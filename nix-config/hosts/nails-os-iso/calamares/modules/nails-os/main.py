#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# NAILS OS Calamares installer module.
#
# Replaces the stock "nixos" module.  When the exec phase runs this module:
#
#   1. Copies the NAILS OS flake from /etc/nixos into the target root.
#   2. Detects partition UUIDs (EFI, LUKS) from globalStorage + blkid.
#      LUKS on the root partition is mandatory; the install is aborted if
#      the user chose not to encrypt.
#   3. Writes hardware-configuration.nix with the real UUIDs
#      and the impermanence filesystem layout (tmpfs /, /persist, /nix bind).
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


def make_hardware_config(boot_uuid, luks_uuid, initrd_modules):
    """Return the content of hardware-configuration.nix for NAILS OS.

    Layout (matches impermanence.nix + storage.nix expectations):
      /        → tmpfs
      /persist → LUKS2-encrypted ext4  (device = /dev/disk/by-uuid/<luks_uuid>)
      /nix     → bind mount from /persist/nix
      /boot    → FAT32 EFI partition   (device = /dev/disk/by-uuid/<boot_uuid>)

    The LUKS container is named "persist" so it opens as /dev/mapper/persist.
    """
    modules_nix = "[ " + " ".join('"{}"'.format(m) for m in initrd_modules) + " ]"

    return """\
# Generated by the NAILS OS Calamares installer. Do not edit by hand.
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

  fileSystems."/boot" = {{
    device = "/dev/disk/by-uuid/{boot_uuid}";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  }};

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}}
""".format(
        modules=modules_nix,
        luks_uuid=luks_uuid,
        boot_uuid=boot_uuid,
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

    # boot_device: the plain FAT32 EFI partition (/boot).
    # We must prefer a FAT32 partition over any LUKS-encrypted /boot partition
    # because our layout has an unencrypted EFI partition.  If the user somehow
    # created an encrypted /boot, we will see fsName=luks2 on mountPoint=/boot —
    # we skip those and only accept fat32/vfat.
    boot_device = None  # plain FAT32 /boot block device
    luks_device = None  # raw LUKS2 block device for root (not the mapper)
    luks_passphrase = None  # passphrase as entered in the Calamares UI
    luks_mapper_name = None  # e.g. "luks-<uuid>" — name opened by Calamares

    for part in partitions:
        mp = part.get("mountPoint", "")
        dev = part.get("device", "")
        # Calamares uses "fs" (older) or "fsName" (newer) for the filesystem type.
        fs = (part.get("fileSystemType") or part.get("fs") or "").lower()

        libcalamares.utils.debug("  partition: dev={} mp={} fs={}".format(dev, mp, fs))

        # --- EFI / boot partition ---
        # Accept only a plaintext FAT32 partition for /boot.  If fsName is
        # luks2 the mount point is /boot for an encrypted-boot layout which
        # we do NOT support — skip it so the lsblk fallback can find the
        # real FAT32 EFI partition.
        if mp == "/boot" and fs in ("fat32", "vfat"):
            boot_device = dev
            libcalamares.utils.debug("  → EFI/boot (FAT32, by mountPoint)")
        elif fs in ("fat32", "vfat") and boot_device is None:
            boot_device = dev
            libcalamares.utils.debug("  → EFI (FAT32, tentative)")

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

    # Fallback: scan lsblk for the FAT32 mounted at <root>/boot.
    if not boot_device:
        target_boot_mp = os.path.join(root, "boot")
        libcalamares.utils.debug(
            "boot_device not found in globalStorage; scanning lsblk for {}".format(
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

    if not boot_device:
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

    boot_uuid = blkid_uuid(boot_device)
    luks_uuid = blkid_uuid(luks_device)

    libcalamares.utils.debug("boot UUID = {}".format(boot_uuid))
    libcalamares.utils.debug("luks UUID = {}".format(luks_uuid))

    if not boot_uuid:
        return (_("Installation error"), _("Could not read UUID of EFI partition."))
    if not luks_uuid:
        return (_("Installation error"), _("Could not read UUID of LUKS partition."))

    # ------------------------------------------------------------------
    # 3. Write hardware-configuration.nix
    # ------------------------------------------------------------------
    status = _("Writing hardware configuration")
    libcalamares.job.setprogress(0.20)

    initrd_modules = get_initrd_modules()
    libcalamares.utils.debug("initrd modules: {}".format(initrd_modules))

    hw_config = make_hardware_config(boot_uuid, luks_uuid, initrd_modules)
    hw_dest = os.path.join(target_nixos, "hardware-configuration.nix")
    try:
        write_file(hw_dest, hw_config)
    except RuntimeError as e:
        return (_("Failed to write hardware configuration"), str(e))

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
        for d in [
            "etc/nixos",
            "var/lib/nixos",
            "var/lib/AccountsService",
            "var/lib/systemd/backlight",
            "var/lib/systemd/rfkill",
            "var/lib/bluetooth",
        ]:
            run_cmd("mkdir", "-p", os.path.join(persist_root, d))

        run_cmd("mkdir", "-p", os.path.join(persist_root, "home", username))
        run_cmd("chmod", "700", os.path.join(persist_root, "home", username))

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

    # ------------------------------------------------------------------
    # 9. Copy the flake into /persist/etc/nixos so it survives reboots
    #    (impermanence.nix persists /etc/nixos from /persist/etc/nixos)
    # ------------------------------------------------------------------
    status = _("Persisting configuration")
    libcalamares.job.setprogress(0.97)

    persist_nixos = os.path.join(persist_root, "etc", "nixos")
    try:
        run_cmd("mkdir", "-p", persist_nixos)
        run_cmd("cp", "-a", os.path.join(target_nixos, "."), persist_nixos)
    except RuntimeError as e:
        return (_("Failed to persist configuration"), str(e))

    libcalamares.job.setprogress(1.0)
    return None
