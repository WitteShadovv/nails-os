#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# NAILS OS Calamares installer module.
#
# Replaces the stock "nixos" module.  When the exec phase runs this module:
#
#   1. Copies the NAILS OS flake from /etc/nixos into the target root.
#   2. Detects boot mode (EFI or BIOS) and partition UUIDs from globalStorage
#      + blkid/lsblk.  LUKS on the root partition is mandatory; the install
#      is aborted if the user chose not to encrypt.
#   3. Writes hardware-configuration.nix with the real UUIDs and the
#      impermanence filesystem layout (tmpfs /, /persist, /nix bind).
#   3b. Writes hosts/nails-os/boot-mode.nix with the detected bootloader
#      config (systemd-boot for EFI, GRUB for BIOS).
#   4. Writes hosts/nails-os/hostname.nix with the user-chosen hostname.
#   5. Writes modules/secrets/<user>.passwd and modules/secrets.nix.
#   6. Bind-mounts <root>/nix -> <root>/persist/nix so nixos-install writes
#      the Nix store into the right place on the LUKS ext4.
#   7. Runs nixos-install --flake <target>/etc/nixos#nails-os.
#   8. Unmounts the bind-mount.
#   9. Copies the flake into /persist/etc/nixos so it survives reboots.
#
# Calamares globalStorage keys consumed:
#   rootMountPoint   – target mount point            (set by mount module)
#   partitions       – list of partition dicts       (set by partition module)
#     each dict may carry:
#       device, mountPoint, fs/fsName, uuid, luksPassphrase, luksMapperName
#   hostname         – chosen hostname               (set by users module)
#   username         – chosen login name             (set by users module)
#   fullname         – chosen full name              (set by users module)
#   password         – obscured user password        (set by users module)
#   keyboardLayout   – X11 keyboard layout           (set by keyboard module)
#   keyboardVariant  – X11 keyboard variant          (set by keyboard module)
#   locationRegion   – timezone region               (set by locale module)
#   locationZone     – timezone zone                 (set by locale module)

import glob as _glob
import gettext
import json
import os
import re
import subprocess

import libcalamares

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext


def pretty_name():
    return _("Installing NAILS OS.")


status = pretty_name()


def pretty_status_message():
    return status


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def run_cmd(*cmd, stdin=None, check=True):
    """Run *cmd*, return stdout string.  Raises RuntimeError on failure.

    NOTE: Calamares runs the exec phase as root; we do NOT wrap commands in
    pkexec (that is for non-root callers requesting privilege elevation and
    will be denied when the caller is already root).
    """
    proc = subprocess.run(
        list(cmd),
        input=stdin.encode() if isinstance(stdin, str) else stdin,
        capture_output=True,
    )
    if check and proc.returncode != 0:
        msg = (proc.stderr or proc.stdout or b"").decode("utf-8", errors="replace")
        raise RuntimeError("{}: {}".format(" ".join(cmd), msg))
    return proc.stdout.decode("utf-8", errors="replace").strip()


def run_stream(*cmd):
    """Run *cmd* streaming each line to the Calamares debug log.
    Returns (returncode, full_output_string)."""
    proc = subprocess.Popen(
        list(cmd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    lines = []
    for raw in proc.stdout:
        line = raw.decode("utf-8", errors="replace").rstrip()
        libcalamares.utils.debug(line)
        lines.append(line)
    proc.wait()
    return proc.returncode, "\n".join(lines)


def write_file(path, content, mode=None):
    """Write *content* to *path*, optionally set *mode*."""
    run_cmd("tee", path, stdin=content)
    if mode:
        run_cmd("chmod", mode, path)


def _calamares_deobscure(s):
    """Reverse the KStringHandler::obscure XOR applied by Calamares' users
    module before it stores the password in GlobalStorage under key "password".

    The algorithm is self-inverse: obscure(obscure(x)) == x.
    Characters with unicode value <= 0x21 are left as-is;
    all others are mapped to (0x1001F - codepoint).
    """
    result = []
    for ch in s:
        cp = ord(ch)
        result.append(ch if cp <= 0x21 else chr(0x1001F - cp))
    return "".join(result)


def hash_password(plaintext):
    """Return a SHA-512 crypt hash suitable for shadow(5)."""
    proc = subprocess.run(
        ["openssl", "passwd", "-6", "-stdin"],
        input=plaintext.encode(),
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError("openssl passwd failed: " + proc.stderr.decode())
    return proc.stdout.decode().strip()


def blkid_uuid(device):
    """Return the filesystem UUID of *device*, or None if unavailable."""
    try:
        out = run_cmd("blkid", "-s", "UUID", "-o", "value", device, check=False)
        return out.strip() or None
    except Exception:
        return None


def blkid_type(device):
    """Return the filesystem TYPE of *device* (e.g. 'crypto_LUKS')."""
    try:
        out = run_cmd("blkid", "-s", "TYPE", "-o", "value", device, check=False)
        return out.strip() or None
    except Exception:
        return None


def find_luks_backing_device(mapper_dev):
    """Given /dev/mapper/X (already-opened LUKS device), return the raw
    LUKS partition (e.g. /dev/sda2) by reading /sys/block/<dm>/slaves/.

    Returns None if the backing device cannot be determined or is not LUKS.
    """
    try:
        real = os.path.realpath(mapper_dev)  # e.g. /dev/dm-0
        dm_name = os.path.basename(real)  # e.g. dm-0
        slaves_dir = "/sys/block/{}/slaves".format(dm_name)
        for slave in _glob.glob(os.path.join(slaves_dir, "*")):
            candidate = "/dev/" + os.path.basename(slave)
            t = blkid_type(candidate)
            if t and "luks" in t.lower():
                return candidate
    except Exception as ex:
        libcalamares.utils.debug(
            "find_luks_backing_device({}) failed: {}".format(mapper_dev, ex)
        )
    return None


def get_initrd_modules():
    """Return a de-duplicated, sorted list of kernel modules to add to initrd.
    We detect disk-controller modules from the live system's lsmod output.
    """
    modules = ["dm_mod", "dm_crypt", "ext4", "vfat"]
    try:
        lsmod_out = run_cmd("lsmod", check=False)
        loaded = set()
        for line in lsmod_out.splitlines()[1:]:
            name = line.split()[0] if line.strip() else ""
            if name:
                loaded.add(name)
        for mod in [
            "ahci",
            "nvme",
            "nvme_core",
            "virtio_blk",
            "sd_mod",
            "ata_piix",
            "xhci_pci",
            "ehci_pci",
            "uhci_hcd",
            "usb_storage",
        ]:
            if mod in loaded:
                modules.append(mod)
    except Exception:
        pass
    for mod in ["ahci", "sd_mod", "ata_piix"]:
        if mod not in modules:
            modules.append(mod)
    return sorted(set(modules))


def is_efi_boot():
    """Return True when the installer is running under UEFI firmware.

    The kernel populates /sys/firmware/efi only on UEFI systems.  On
    BIOS/CSM machines the directory does not exist.
    """
    return os.path.isdir("/sys/firmware/efi")


def get_disk_device(partition_dev):
    """Return the parent whole-disk device for *partition_dev*.

    E.g. /dev/sda2 → /dev/sda,  /dev/nvme0n1p3 → /dev/nvme0n1.

    Tries lsblk PKNAME first; falls back to a regex that strips the
    trailing partition number (and optional 'p' separator for NVMe).
    """
    try:
        pkname = (
            run_cmd("lsblk", "-no", "PKNAME", partition_dev, check=False)
            .splitlines()[0]
            .strip()
        )
        if pkname:
            return "/dev/" + pkname
    except Exception as ex:
        libcalamares.utils.debug(
            "get_disk_device({}) lsblk failed: {}".format(partition_dev, ex)
        )
    m = re.match(r"^(/dev/(?:nvme\d+n\d+|[a-z]+))p?\d+$", partition_dev)
    if m:
        return m.group(1)
    return None


def read_uid_gid(root, username):
    """Return (uid, gid) strings for *username* in the target root, or (None, None)."""
    passwd_path = os.path.join(root, "etc", "passwd")
    try:
        with open(passwd_path, "r", encoding="utf-8") as handle:
            for line in handle:
                if not line or line.startswith("#"):
                    continue
                if not line.startswith(username + ":"):
                    continue
                parts = line.strip().split(":")
                if len(parts) >= 4:
                    return parts[2], parts[3]
    except Exception as ex:
        libcalamares.utils.debug(
            "read_uid_gid({}, {}) failed: {}".format(passwd_path, username, ex)
        )
    return None, None


# ---------------------------------------------------------------------------
# hardware-configuration.nix writer
# ---------------------------------------------------------------------------


def make_hardware_config(
    boot_uuid,
    luks_uuid,
    initrd_modules,
    efi_mode=True,
    grub_disk_device=None,
):
    """Return the content of hardware-configuration.nix for NAILS OS.

    Layout (both modes):
      /        → tmpfs
      /persist → LUKS-encrypted ext4  (device = /dev/disk/by-uuid/<luks_uuid>)
      /nix     → bind mount from /persist/nix

    EFI:  /boot/efi → FAT32 vfat  (EFI system partition, separate partition)
    BIOS: /boot → bind mount from /persist/boot (inside LUKS1 ext4)

    The LUKS container is named "persist" so it opens as /dev/mapper/persist.
    """
    modules_nix = "[ " + " ".join('"{}"'.format(m) for m in initrd_modules) + " ]"

    if efi_mode:
        boot_fs_block = (
            '  fileSystems."/boot/efi" = {{\n'
            '    device = "/dev/disk/by-uuid/{boot_uuid}";\n'
            '    fsType = "vfat";\n'
            '    options = [ "fmask=0077" "dmask=0077" ];\n'
            "  }};"
        ).format(boot_uuid=boot_uuid)
    else:
        # BIOS mode: /boot lives inside the LUKS1 ext4.
        # At runtime, /persist is the decrypted ext4 and /boot binds from /persist/boot.
        # GRUB (with enableCryptodisk) reads the kernel/initrd from the LUKS1 container.
        boot_fs_block = (
            "  # BIOS mode: /boot is inside the LUKS1 ext4, bound from /persist/boot.\n"
            '  fileSystems."/boot" = {\n'
            '    device = "/persist/boot";\n'
            '    fsType = "none";\n'
            '    options = [ "bind" ];\n'
            '    depends = [ "/persist" ];\n'
            "    neededForBoot = true;\n"
            "  };"
        )

    return """\
{{ config, lib, pkgs, modulesPath, ... }}:
{{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = {modules};
  boot.initrd.kernelModules = [ "dm_crypt" "dm_mod" ];

  # LUKS2 container — opens as /dev/mapper/persist
  boot.initrd.luks.devices."persist" = {{
    device = "/dev/disk/by-uuid/{luks_uuid}";
    preLVM  = true;
    allowDiscards = true;
  }};

  fileSystems."/" = {{
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" "size=4G" ];
  }};

  fileSystems."/persist" = {{
    device = "/dev/mapper/persist";
    fsType  = "ext4";
    neededForBoot = true;
  }};

  fileSystems."/nix" = {{
    device  = "/persist/nix";
    fsType  = "none";
    options = [ "bind" ];
    depends = [ "/persist" ];
    neededForBoot = true;
  }};

{boot_fs_block}

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}}
""".format(
        modules=modules_nix,
        luks_uuid=luks_uuid,
        boot_fs_block=boot_fs_block,
    )


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def run():
    global status

    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint")

    if not root:
        return (_("Installation error"), _("rootMountPoint is not set."))

    target_nixos = os.path.join(root, "etc", "nixos")

    # ------------------------------------------------------------------
    # 1. Copy the NAILS OS flake into the target
    # ------------------------------------------------------------------
    status = _("Copying NAILS OS configuration")
    libcalamares.job.setprogress(0.05)
    libcalamares.utils.debug("Copying /etc/nixos -> {}".format(target_nixos))

    try:
        run_cmd("mkdir", "-p", target_nixos)
        run_cmd("mkdir", "-p", os.path.join(target_nixos, "hosts", "nails-os"))
        run_cmd("mkdir", "-p", os.path.join(target_nixos, "modules", "secrets"))
        run_cmd("chmod", "755", target_nixos)
        run_cmd("cp", "-aL", "/etc/nixos/.", target_nixos)
        run_cmd("chmod", "-R", "u+w", target_nixos)
    except RuntimeError as e:
        return (_("Failed to copy NAILS OS configuration"), str(e))

    # ------------------------------------------------------------------
    # 2. Detect partition layout from globalStorage
    # ------------------------------------------------------------------
    status = _("Detecting partition layout")
    libcalamares.job.setprogress(0.10)

    partitions = gs.value("partitions") or []
    libcalamares.utils.debug("partitions from globalStorage: {}".format(partitions))

    # Detect boot mode: /sys/firmware/efi exists only on UEFI systems.
    efi_mode = is_efi_boot()
    grub_disk_device = None
    libcalamares.utils.debug(
        "NAILS OS installer: boot mode = {}".format("EFI" if efi_mode else "BIOS")
    )

    # boot_device: the /boot partition.
    #   EFI mode  — plain FAT32 partition; skip any LUKS-encrypted /boot.
    #   BIOS mode — plain ext4 partition; unencrypted so GRUB can read kernels.
    boot_device = None  # /boot block device
    luks_device = None  # raw LUKS2 block device for root (not the mapper)
    luks_passphrase = None  # passphrase as entered in the Calamares UI
    luks_mapper_name = None  # e.g. "luks-<uuid>" — name opened by Calamares

    for part in partitions:
        mp = part.get("mountPoint", "")
        dev = part.get("device", "")
        # Calamares uses "fs" (older) or "fsName" (newer) for the filesystem type.
        fs = (part.get("fileSystemType") or part.get("fs") or "").lower()

        libcalamares.utils.debug("  partition: dev={} mp={} fs={}".format(dev, mp, fs))

        # --- /boot partition ---
        # EFI: accept only plaintext FAT32.  Skip LUKS-encrypted /boot.
        # BIOS: accept ext4 /boot (unencrypted, GRUB-readable).
        if efi_mode:
            if mp == "/boot" and fs in ("fat32", "vfat"):
                boot_device = dev
                libcalamares.utils.debug("  → EFI/boot (FAT32, by mountPoint)")
            elif fs in ("fat32", "vfat") and boot_device is None:
                boot_device = dev
                libcalamares.utils.debug("  → EFI (FAT32, tentative)")
        else:
            if mp == "/boot" and fs in ("ext4", "ext3", "ext2"):
                boot_device = dev
                libcalamares.utils.debug("  → BIOS /boot (ext4, by mountPoint)")
            elif fs == "ext4" and boot_device is None and mp == "/boot":
                boot_device = dev
                libcalamares.utils.debug("  → BIOS /boot (ext4, tentative)")

        # --- Root / LUKS partition ---
        if mp == "/":
            # Calamares may give us the raw LUKS device or the opened mapper.
            # Check if it is directly LUKS first.
            dev_type = blkid_type(dev) if dev else None
            libcalamares.utils.debug(
                "  root device {} blkid type: {}".format(dev, dev_type)
            )

            if dev_type and "luks" in dev_type.lower():
                luks_device = dev
                libcalamares.utils.debug("  → LUKS (raw partition in globalStorage)")
            elif dev:
                # device is the opened mapper — find the backing LUKS partition
                backing = find_luks_backing_device(dev)
                if backing:
                    luks_device = backing
                    libcalamares.utils.debug(
                        "  → LUKS backing device: {}".format(backing)
                    )
                else:
                    # Last resort: lsblk PKNAME
                    try:
                        pkname = (
                            run_cmd("lsblk", "-no", "PKNAME", dev, check=False)
                            .splitlines()[0]
                            .strip()
                        )
                        if pkname:
                            candidate = "/dev/" + pkname
                            t = blkid_type(candidate)
                            if t and "luks" in t.lower():
                                luks_device = candidate
                                libcalamares.utils.debug(
                                    "  → LUKS via lsblk PKNAME: {}".format(candidate)
                                )
                            else:
                                luks_device = dev
                                libcalamares.utils.debug(
                                    "  → PKNAME {} not LUKS; using mapper".format(
                                        candidate
                                    )
                                )
                        else:
                            luks_device = dev
                    except Exception as ex:
                        libcalamares.utils.debug(
                            "  lsblk PKNAME fallback failed: {}".format(ex)
                        )
                        luks_device = dev

            # --- LUKS passphrase ---
            # Calamares stores the passphrase in the partition dict as
            # "luksPassphrase".  Grab it from the root partition entry.
            passphrase = part.get("luksPassphrase") or ""
            if passphrase:
                luks_passphrase = passphrase
                libcalamares.utils.debug("  → LUKS passphrase found in globalStorage")
            mapper = part.get("luksMapperName") or ""
            if mapper:
                luks_mapper_name = mapper

        # Also check non-root partitions for a passphrase in case Calamares
        # labels the mapper differently (e.g. manual partitioning edge cases).
        if luks_passphrase is None:
            passphrase = part.get("luksPassphrase") or ""
            if passphrase and (part.get("fsName") or "").lower() in ("luks", "luks2"):
                luks_passphrase = passphrase
                libcalamares.utils.debug(
                    "  → LUKS passphrase from non-root LUKS partition {}".format(dev)
                )

    # EFI only: scan lsblk for the /boot device mounted at <root>/boot.
    # BIOS mode has no separate /boot partition — it lives inside the LUKS ext4.
    if not boot_device and efi_mode:
        target_boot_mp = os.path.join(root, "boot")
        libcalamares.utils.debug(
            "EFI boot_device not found in globalStorage; scanning lsblk for {}".format(
                target_boot_mp
            )
        )
        try:
            lsblk_out = run_cmd(
                "lsblk", "-J", "-o", "NAME,FSTYPE,MOUNTPOINT", check=False
            )
            data = json.loads(lsblk_out)

            def scan_boot(nodes):
                for n in nodes:
                    if n.get("mountpoint") == target_boot_mp:
                        return "/dev/" + n["name"]
                    result = scan_boot(n.get("children") or [])
                    if result:
                        return result
                return None

            boot_device = scan_boot(data.get("blockdevices", []))
        except Exception as ex:
            libcalamares.utils.debug("lsblk boot fallback failed: {}".format(ex))

    libcalamares.utils.debug("boot_device    = {}".format(boot_device))
    libcalamares.utils.debug("luks_device    = {}".format(luks_device))
    libcalamares.utils.debug("luks_mapper    = {}".format(luks_mapper_name))
    libcalamares.utils.debug(
        "luks_passphrase present: {}".format(bool(luks_passphrase))
    )

    # EFI requires a separate /boot (FAT32 EFI partition).
    # BIOS does not: /boot lives inside the LUKS1 ext4 at /persist/boot.
    if not boot_device and efi_mode:
        return (
            _("Installation error"),
            _("Could not detect EFI partition. Check partition layout."),
        )
    if not luks_device:
        return (
            _("Installation error"),
            _(
                "NAILS OS requires full-disk encryption. "
                "No LUKS partition was found on the root mount point. "
                "Please go back and enable encryption."
            ),
        )

    # Enforce LUKS: verify the detected device is actually LUKS on disk.
    actual_type = blkid_type(luks_device)
    if not actual_type or "luks" not in actual_type.lower():
        return (
            _("Installation error"),
            _(
                "NAILS OS requires full-disk encryption. "
                "The root partition ({dev}) is not LUKS-encrypted (type: {t}). "
                "Please go back and enable encryption."
            ).format(dev=luks_device, t=actual_type or "unknown"),
        )

    if not luks_passphrase:
        return (
            _("Installation error"),
            _(
                "LUKS passphrase was not provided by Calamares. "
                "Please go back and set an encryption passphrase."
            ),
        )

    boot_uuid = blkid_uuid(boot_device) if boot_device else None
    luks_uuid = blkid_uuid(luks_device)

    libcalamares.utils.debug("boot UUID = {}".format(boot_uuid))
    libcalamares.utils.debug("luks UUID = {}".format(luks_uuid))

    if efi_mode and not boot_uuid:
        return (
            _("Installation error"),
            _("Could not read UUID of EFI partition."),
        )
    if not luks_uuid:
        return (_("Installation error"), _("Could not read UUID of LUKS partition."))

    # For BIOS installs, derive the parent disk from the LUKS root partition.
    # There is no separate /boot partition — GRUB installs to the disk MBR.
    if not efi_mode:
        grub_disk_device = get_disk_device(luks_device)
        if not grub_disk_device:
            return (
                _("Installation error"),
                _(
                    "Could not determine parent disk device for GRUB (LUKS device: {})."
                ).format(luks_device),
            )
        libcalamares.utils.debug(
            "BIOS mode: GRUB disk device = {}".format(grub_disk_device)
        )

    # ------------------------------------------------------------------
    # 3. Write hardware-configuration.nix
    # ------------------------------------------------------------------
    status = _("Writing hardware configuration")
    libcalamares.job.setprogress(0.20)

    initrd_modules = get_initrd_modules()
    libcalamares.utils.debug("initrd modules: {}".format(initrd_modules))

    hw_config = make_hardware_config(
        boot_uuid,
        luks_uuid,
        initrd_modules,
        efi_mode=efi_mode,
        grub_disk_device=grub_disk_device,
    )
    hw_dest = os.path.join(target_nixos, "hardware-configuration.nix")
    try:
        write_file(hw_dest, hw_config)
    except RuntimeError as e:
        return (_("Failed to write hardware configuration"), str(e))

    # ------------------------------------------------------------------
    # 3b. Write boot-mode.nix (consumed by hosts/nails-os/default.nix)
    # ------------------------------------------------------------------
    if efi_mode:
        boot_mode_nix = (
            "# Written by the Calamares installer — EFI boot mode.\n"
            "{ ... }:\n"
            "{\n"
            "  boot.loader.systemd-boot.enable = true;\n"
            "  boot.loader.efi.canTouchEfiVariables = true;\n"
            '  boot.loader.efi.efiSysMountPoint = "/boot/efi";\n'
            "  boot.loader.grub.enable = false;\n"
            "}\n"
        )
    else:
        boot_mode_nix = (
            "# Written by the Calamares installer — BIOS boot mode.\n"
            "{ ... }:\n"
            "{\n"
            "  boot.loader.systemd-boot.enable = false;\n"
            "  boot.loader.grub.enable = true;\n"
            '  boot.loader.grub.device = "' + grub_disk_device + '";\n'
            "  boot.loader.grub.efiSupport = false;\n"
            '  boot.loader.grub.fsIdentifier = "uuid";\n'
            "  # GRUB unlocks the LUKS1 container to read /boot.\n"
            "  boot.loader.grub.enableCryptodisk = true;\n"
            "}\n"
        )

    try:
        write_file(
            os.path.join(target_nixos, "hosts", "nails-os", "boot-mode.nix"),
            boot_mode_nix,
        )
    except RuntimeError as e:
        return (_("Failed to write boot mode configuration"), str(e))

    # ------------------------------------------------------------------
    # 4. Write hostname.nix
    # ------------------------------------------------------------------
    status = _("Configuring hostname")
    libcalamares.job.setprogress(0.25)

    raw_hostname = gs.value("hostname") or "nails-os"
    hostname = re.sub(r"[^a-zA-Z0-9\-]", "-", raw_hostname)
    hostname = re.sub(r"-{2,}", "-", hostname).strip("-").lower()
    if not hostname:
        hostname = "nails-os"

    libcalamares.utils.debug("hostname: {}".format(hostname))

    hostname_nix = (
        "# Written by the Calamares installer.\n"
        "{{ ... }}:\n"
        "{{\n"
        '  networking.hostName = "{}";\n'
        "}}\n"
    ).format(hostname)

    try:
        write_file(
            os.path.join(target_nixos, "hosts", "nails-os", "hostname.nix"),
            hostname_nix,
        )
    except RuntimeError as e:
        return (_("Failed to write hostname configuration"), str(e))

    # ------------------------------------------------------------------
    # 5. Write user password hash + locale/keyboard nix snippets
    # ------------------------------------------------------------------
    status = _("Configuring users")
    libcalamares.job.setprogress(0.30)

    # Username: Calamares stores it as "username".  We fall back to "amnesia"
    # because NAILS OS hardcodes that account name in users.nix.
    username = (gs.value("username") or "amnesia").strip() or "amnesia"
    fullname = (gs.value("fullname") or username).strip()
    libcalamares.utils.debug("username: {}  fullname: {}".format(username, fullname))

    # Password: stored as "password" in GS, XOR-obscured.
    raw_password = gs.value("password") or ""
    user_password = _calamares_deobscure(raw_password)
    if not user_password:
        return (_("Installation error"), _("No user password was provided."))

    try:
        passwd_hash = hash_password(user_password)
    except RuntimeError as e:
        return (_("Failed to hash password"), str(e))

    secrets_dir = os.path.join(target_nixos, "modules", "secrets")
    passwd_file = os.path.join(secrets_dir, "{}.passwd".format(username))
    secrets_nix = os.path.join(target_nixos, "modules", "secrets.nix")

    secrets_nix_content = (
        "# Written by the Calamares installer.\n"
        "{{ ... }}:\n"
        "{{\n"
        "  users.users.{user}.hashedPasswordFile =\n"
        "    toString ./secrets/{user}.passwd;\n"
        "}}\n"
    ).format(user=username)

    try:
        write_file(passwd_file, passwd_hash, mode="600")
        write_file(secrets_nix, secrets_nix_content)
    except RuntimeError as e:
        return (_("Failed to write user credentials"), str(e))

    # ------------------------------------------------------------------
    # 5b. Write locale/timezone/keyboard nix snippet
    # ------------------------------------------------------------------
    status = _("Configuring locale and keyboard")
    libcalamares.job.setprogress(0.35)

    region = gs.value("locationRegion") or ""
    zone = gs.value("locationZone") or ""
    timezone = "{}/{}".format(region, zone) if region and zone else "UTC"

    kb_layout = gs.value("keyboardLayout") or "us"
    kb_variant = gs.value("keyboardVariant") or ""

    locale_nix_lines = [
        "# Written by the Calamares installer.",
        "{ ... }:",
        "{",
        '  time.timeZone = "{}";'.format(timezone),
        '  i18n.defaultLocale = "en_US.UTF-8";',
        "  services.xserver.xkb = {",
        '    layout  = "{}";'.format(kb_layout),
        '    variant = "{}";'.format(kb_variant),
        "  };",
        "}",
        "",
    ]
    locale_nix_content = "\n".join(locale_nix_lines)

    locale_dest = os.path.join(target_nixos, "hosts", "nails-os", "locale.nix")
    try:
        write_file(locale_dest, locale_nix_content)
    except RuntimeError as e:
        return (_("Failed to write locale configuration"), str(e))

    libcalamares.utils.debug(
        "locale: timezone={} layout={} variant={}".format(
            timezone, kb_layout, kb_variant
        )
    )

    # ------------------------------------------------------------------
    # 5c. Write network-mode.nix if user chose to disable Tor
    #
    # The packagechooser module stores the user's selection in GlobalStorage
    # under key "packagechooser_packagechooser-tor".  Values are "tor" (default)
    # or "direct".  If the key is absent we keep Tor enabled (safe default).
    # ------------------------------------------------------------------
    tor_choice = gs.value("packagechooser_packagechooser-tor") or "tor"
    tor_enabled = tor_choice != "direct"
    libcalamares.utils.debug(
        "packagechooser_torconfig={!r}  torEnabled={}".format(tor_choice, tor_enabled)
    )

    if not tor_enabled:
        status = _("Configuring network mode (direct)")
        libcalamares.job.setprogress(0.37)

        network_mode_nix = (
            "# Written by the Calamares installer — user chose direct networking.\n"
            "{ lib, ... }:\n"
            "{\n"
            "  nailsOs.tor.enable = false;\n"
            '  networking.nameservers = lib.mkForce [ "9.9.9.9" "149.112.112.112" ];\n'
            '  networking.networkmanager.dns = lib.mkForce "default";\n'
            "}\n"
        )

        network_mode_dest = os.path.join(
            target_nixos, "hosts", "nails-os", "network-mode.nix"
        )
        try:
            write_file(network_mode_dest, network_mode_nix)
        except RuntimeError as e:
            return (_("Failed to write network mode configuration"), str(e))

        libcalamares.utils.debug("Wrote network-mode.nix (Tor disabled)")
    else:
        libcalamares.utils.debug("Tor enabled (default) — no network-mode.nix written")

    # ------------------------------------------------------------------
    # 5d. Write shell-history-mode.nix if user chose to enable shell history
    #
    # The packagechooser module stores the user's selection in GlobalStorage
    # under key "packagechooser_packagechooser-history".  Values are "disabled"
    # (default) or "enabled".  If the key is absent we keep history disabled
    # (safe default).
    # ------------------------------------------------------------------
    history_choice = gs.value("packagechooser_packagechooser-history") or "disabled"
    history_enabled = history_choice == "enabled"
    libcalamares.utils.debug(
        "packagechooser_historyconfig={!r}  historyEnabled={}".format(
            history_choice, history_enabled
        )
    )

    if history_enabled:
        status = _("Configuring shell history (enabled)")
        libcalamares.job.setprogress(0.38)

        shell_history_nix = (
            "# Written by the Calamares installer — user chose to enable shell history.\n"
            "{ lib, ... }:\n"
            "{\n"
            "  nailsOs.shellHistory.disable = false;\n"
            "}\n"
        )

        shell_history_dest = os.path.join(
            target_nixos, "hosts", "nails-os", "shell-history-mode.nix"
        )
        try:
            write_file(shell_history_dest, shell_history_nix)
        except RuntimeError as e:
            return (_("Failed to write shell history configuration"), str(e))

        libcalamares.utils.debug("Wrote shell-history-mode.nix (history enabled)")
    else:
        libcalamares.utils.debug(
            "Shell history disabled (default) — no shell-history-mode.nix written"
        )

    # ------------------------------------------------------------------
    # 5e. Write home-persistence-mode.nix if user chose full home persistence
    #
    # The packagechooser module stores the user's selection in GlobalStorage
    # under key "packagechooser_packagechooser-home-persistence".  Values are
    # "selective" (default) or "full".  If the key is absent we use selective
    # persistence (safe default).
    # ------------------------------------------------------------------
    home_choice = (
        gs.value("packagechooser_packagechooser-home-persistence") or "selective"
    )
    home_persistence_full = home_choice == "full"
    libcalamares.utils.debug(
        "packagechooser_homepersistenceconfig={!r}  homePersistenceFull={}".format(
            home_choice, home_persistence_full
        )
    )

    if home_persistence_full:
        status = _("Configuring home persistence (full)")
        libcalamares.job.setprogress(0.39)

        home_persistence_nix = (
            "# Written by the Calamares installer — user chose full home persistence.\n"
            "{ ... }:\n"
            "{\n"
            "  nailsOs.homePersistence.selective = false;\n"
            "}\n"
        )

        home_persistence_dest = os.path.join(
            target_nixos, "hosts", "nails-os", "home-persistence-mode.nix"
        )
        try:
            write_file(home_persistence_dest, home_persistence_nix)
        except RuntimeError as e:
            return (_("Failed to write home persistence configuration"), str(e))

        libcalamares.utils.debug("Wrote home-persistence-mode.nix (full home)")
    else:
        libcalamares.utils.debug(
            "Home persistence selective (default) — no home-persistence-mode.nix written"
        )

    # ------------------------------------------------------------------
    # 6. Prepare the /persist directory tree
    #
    # Layout on the LUKS ext4 (mounted at <root> by Calamares):
    #
    #   <root>/                  ← ext4 root  =  /persist at runtime
    #   <root>/nix/store/...     ← Nix store  =  /persist/nix/store at runtime
    #                              (runtime /nix is a bind of /persist/nix)
    #
    # nixos-install writes directly to <root>/nix/store, which is already the
    # correct physical location on the ext4.  No bind-mount is needed.
    #
    # persist_root == root because the ext4 IS the /persist volume — there is
    # no "persist/" subdirectory on the ext4; the ext4 root itself is mounted
    # at /persist at runtime.
    # ------------------------------------------------------------------
    status = _("Preparing filesystem layout")
    libcalamares.job.setprogress(0.40)

    # The ext4 mount point IS the persist root at runtime.
    persist_root = root

    try:
        # Create persisted directories that impermanence expects at boot.
        dirs = [
            "etc/nixos",
            "var/lib/nixos",
            "var/lib/AccountsService",
            "var/lib/systemd/backlight",
            "var/lib/systemd/rfkill",
            "var/lib/bluetooth",
        ]
        # BIOS mode: /boot lives inside the LUKS ext4 at /persist/boot.
        # Create it here so nixos-install can write GRUB files into it.
        if not efi_mode:
            dirs.append("boot")
        for d in dirs:
            run_cmd("mkdir", "-p", os.path.join(persist_root, d))

        # Create home directory backing store in /persist.
        # Layout differs based on the persistence mode chosen by the user:
        #   full     → one bind mount covering /home/amnesia entirely
        #   selective → individual bind mounts per curated subdirectory
        # In both cases chown -R in step 8 fixes ownership recursively.
        home_persist = os.path.join(persist_root, "home", username)
        run_cmd("mkdir", "-p", home_persist)
        run_cmd("chmod", "700", home_persist)

        if not home_persistence_full:
            # Selective mode: pre-create each persisted subdirectory so that
            # impermanence can bind-mount them on first boot without needing
            # to create them from the initrd (where UIDs may not yet be set).
            selective_subdirs = [
                "Documents",
                "Downloads",
                "Music",
                "Pictures",
                "Videos",
                "Desktop",
                os.path.join(".config", "dconf"),
                os.path.join(".local", "share", "keyrings"),
                ".ssh",
                ".gnupg",
            ]
            for subdir in selective_subdirs:
                subdir_path = os.path.join(home_persist, subdir)
                run_cmd("mkdir", "-p", subdir_path)
                # Cryptographic and credential directories require strict 700.
                if subdir in (
                    ".ssh",
                    ".gnupg",
                    os.path.join(".local", "share", "keyrings"),
                ):
                    run_cmd("chmod", "700", subdir_path)

    except RuntimeError as e:
        return (_("Failed to prepare filesystem layout"), str(e))

    # ------------------------------------------------------------------
    # 7. Install NAILS OS from the flake
    # ------------------------------------------------------------------
    status = _("Installing NAILS OS (this will take a while)")
    libcalamares.job.setprogress(0.45)
    libcalamares.utils.debug(
        "Running nixos-install --flake {}/etc/nixos#nails-os".format(root)
    )

    proxy_prefix = []
    for var in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"):
        val = os.environ.get(var)
        if val:
            proxy_prefix.append("{}={}".format(var, val))
    if proxy_prefix:
        proxy_prefix.insert(0, "env")

    # nixos-install uses <root>/nix/var/nix/builds as the Nix build directory.
    # Because Calamares mounts the target under /tmp/calamares-root-*, the path
    # /tmp/calamares-root-*/nix/var/nix/builds has /tmp (mode 1777,
    # world-writable) as a parent, which Nix refuses for security reasons.
    # Fix: redirect the build directory to /root/nix-builds (mode 0700, root-
    # owned) which has no world-writable ancestors.
    nix_builds_dir = "/root/nix-builds"
    try:
        run_cmd("mkdir", "-p", nix_builds_dir)
        run_cmd("chmod", "700", nix_builds_dir)
    except RuntimeError as e:
        libcalamares.utils.debug(
            "Warning: could not create {}: {}".format(nix_builds_dir, e)
        )

    install_cmd = proxy_prefix + [
        "nixos-install",
        "--no-root-passwd",
        "--root",
        root,
        "--flake",
        "{}/etc/nixos#nails-os".format(root),
        "--option",
        "build-dir",
        nix_builds_dir,
    ]

    rc, output = run_stream(*install_cmd)

    if rc != 0:
        return (_("nixos-install failed"), output)

    # ------------------------------------------------------------------
    # 8. Fix ownership of the persisted home directory
    # ------------------------------------------------------------------
    status = _("Fixing home directory permissions")
    libcalamares.job.setprogress(0.90)

    uid, gid = read_uid_gid(root, username)
    if not uid or not gid:
        return (
            _("Installation error"),
            _("Could not determine UID/GID for user '{}'.").format(username),
        )

    try:
        run_cmd(
            "chown",
            "-R",
            "{}:{}".format(uid, gid),
            os.path.join(persist_root, "home", username),
        )
        run_cmd("chmod", "700", os.path.join(persist_root, "home", username))
    except RuntimeError as e:
        return (_("Failed to set home ownership"), str(e))

    # Step 9 is no longer needed: target_nixos IS persist_root/etc/nixos
    # (persist_root == root, and root is where nixos-install writes the flake).
    # The config is already at the correct location on the ext4 — /persist/etc/nixos
    # at runtime — so no copy is required.

    libcalamares.job.setprogress(1.0)
    return None
