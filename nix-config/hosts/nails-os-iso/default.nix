{ pkgs, modulesPath, ... }:
let
  nixConfig = builtins.path {
    path = ../..;
    name = "nix-config";
  };
  oneClickInstall = pkgs.writeShellScriptBin "nails-os-one-click-install" ''
        set -euo pipefail

        if [ "$(id -u)" -ne 0 ]; then
          exec sudo -E "$0" "$@"
        fi

        display=$(printenv DISPLAY || true)
        if [ -n "$display" ] && command -v zenity >/dev/null 2>&1; then
          zenity --warning --width=600 --text="DANGER: THIS WILL ERASE A DISK\n\nThis installer will DELETE ALL DATA on the selected disk.\nMake sure you have backups. There is NO UNDO."

          mapfile -t disks < <(lsblk -dn -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk"{print $1 "|" $2 "|" $3}')
          if [ "''${#disks[@]}" -eq 0 ]; then
            zenity --error --text="No disks found."
            exit 1
          fi

          args=()
          for entry in "''${disks[@]}"; do
            IFS="|" read -r name size model <<<"$entry"
            args+=(FALSE "/dev/$name" "$size" "$model")
          done

          disk=$(zenity --list --radiolist --width=700 --height=400 \
            --title="Select target disk (WILL ERASE)" \
            --column="Pick" --column="Disk" --column="Size" --column="Model" \
            "''${args[@]}") || exit 1

          confirm=$(zenity --entry --width=600 \
            --text="Type 'ERASE $disk' to confirm you want to wipe this disk:" ) || exit 1
          if [ "$confirm" != "ERASE $disk" ]; then
            zenity --info --text="Aborted."
            exit 1
          fi

          final=$(zenity --entry --width=600 \
            --text="Last chance. Type 'INSTALL' to proceed with erasing $disk:" ) || exit 1
          if [ "$final" != "INSTALL" ]; then
            zenity --info --text="Aborted."
            exit 1
          fi

          pass1=$(zenity --password --width=400 --text="Set LUKS passphrase (used for /nix and /persist):") || exit 1
          pass2=$(zenity --password --width=400 --text="Confirm LUKS passphrase:") || exit 1
          if [ "$pass1" != "$pass2" ]; then
            zenity --error --text="Passphrases do not match."
            exit 1
          fi

          userpass1=$(zenity --password --width=400 --text="Set login password for user 'amnesia':") || exit 1
          userpass2=$(zenity --password --width=400 --text="Confirm login password:") || exit 1
          if [ -z "$userpass1" ] || [ "$userpass1" != "$userpass2" ]; then
            zenity --error --text="User passwords do not match or are empty."
            exit 1
          fi
        else
          echo "GUI not available; falling back to terminal prompts."
          echo "DANGER: THIS WILL ERASE A DISK"
          echo "This installer will DELETE ALL DATA on the selected disk."
          echo "Make sure you have backups. There is NO UNDO."
          echo
          lsblk -d -o NAME,SIZE,MODEL,TYPE
          echo
          read -r -p "Enter target disk (e.g., /dev/sda or /dev/nvme0n1): " disk

          if ! lsblk -dn -o TYPE "$disk" 2>/dev/null | grep -qx "disk"; then
            echo "ERROR: '$disk' is not a disk device."
            exit 1
          fi

          echo
          read -r -p "Type 'ERASE $disk' to confirm: " confirm
          if [ "$confirm" != "ERASE $disk" ]; then
            echo "Aborted."
            exit 1
          fi

          echo
          echo "About to erase $disk and install NAILS OS."
          read -r -p "Last chance. Type 'INSTALL' to proceed: " final
          if [ "$final" != "INSTALL" ]; then
            echo "Aborted."
            exit 1
          fi

          echo "Set LUKS passphrase (used for both /nix and /persist):"
          read -r -s -p "Passphrase: " pass1; echo
          read -r -s -p "Confirm: " pass2; echo
          if [ "$pass1" != "$pass2" ]; then
            echo "ERROR: passphrases do not match."
            exit 1
          fi

          echo "Set login password for user 'amnesia':"
          read -r -s -p "Password: " userpass1; echo
          read -r -s -p "Confirm: " userpass2; echo
          if [ -z "$userpass1" ] || [ "$userpass1" != "$userpass2" ]; then
            echo "ERROR: user passwords do not match or are empty."
            exit 1
          fi
        fi

        echo "Wiping partition table on $disk..."
        wipefs -a "$disk"
        sgdisk --zap-all "$disk"

        echo "Partitioning..."
        parted -s "$disk" mklabel gpt
        parted -s "$disk" mkpart ESP fat32 1MiB 513MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart persist 513MiB 100%

        if echo "$disk" | grep -Eq 'nvme|mmcblk'; then
          p1="$disk"p1
          p2="$disk"p2
        else
          p1="$disk"1
          p2="$disk"2
        fi

        echo "Creating filesystems..."
        mkfs.fat -F 32 -n EFI "$p1"

        printf "%s" "$pass1" | cryptsetup luksFormat "$p2" -
        printf "%s" "$pass1" | cryptsetup open "$p2" persist -
        unset pass1 pass2

        mkfs.ext4 -L persist /dev/mapper/persist

        echo "Mounting target..."
        mount /dev/mapper/persist /mnt
        mkdir -p /mnt/nix /mnt/boot
        mount "$p1" /mnt/boot

        echo "Preparing flake for install..."
        rm -rf /root/nix-config
        mkdir -p /root/nix-config
        cp -aL /etc/nixos/. /root/nix-config/
        mkdir -p /root/nix-config/modules/secrets

        userhash=$(printf "%s" "$userpass1" | openssl passwd -6 -stdin)
        printf "%s" "$userhash" > /root/nix-config/modules/secrets/amnesia.passwd
        chmod 600 /root/nix-config/modules/secrets/amnesia.passwd
        cat > /root/nix-config/modules/secrets.nix <<'EOF'
    { ... }:
    {
      users.users.amnesia.hashedPasswordFile = ./secrets/amnesia.passwd;
    }
    EOF
        chmod 600 /root/nix-config/modules/secrets.nix
        unset userpass1 userpass2 userhash

        echo "Generating hardware config..."
        nixos-generate-config --root /mnt
        cp /mnt/etc/nixos/hardware-configuration.nix /root/nix-config/hosts/nails-os/hardware-configuration.nix
        mkdir -p /mnt/etc/nixos
        cp -a /root/nix-config/. /mnt/etc/nixos/

        echo "Installing NAILS OS..."
        nixos-install --flake /root/nix-config#nails-os --no-root-passwd

        echo "Install complete. Reboot and remove the ISO."
  '';
in {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-gnome.nix"
    ../../modules/base.nix
    ../../modules/security.nix
    ../../modules/packages.nix
    ../../modules/users.nix
    ../../modules/home.nix
  ];

  # ISO specifics
  image.fileName = "nails-os-installer.iso";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;

  networking.hostName = "nails-installer";

  # Provide the full flake config on the ISO for installation.
  environment = {
    etc = {
      "nixos".source = nixConfig;
      "nixos-installer-readme.txt".text = ''
        NAILS OS installer ISO

        Install with:
          1) Partition and mount your target to /mnt
          2) nixos-generate-config --root /mnt
          3) cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hosts/nails-os/hardware-configuration.nix
          4) nixos-install --flake /etc/nixos#nails-os
      '';

      "xdg/applications/nails-os-one-click-install.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=NAILS OS One-Click Install (ERASES DISK)
        Exec=gnome-terminal -- nails-os-one-click-install
        Icon=system-software-install
        Categories=System;
        Terminal=false
      '';
    };

    systemPackages = with pkgs; [
      oneClickInstall
      cryptsetup
      dosfstools
      e2fsprogs
      gptfdisk
      openssl
      parted
      util-linux
      zenity
    ];
  };

  # Live media already runs in a tmpfs/squashfs environment; no LUKS or /persist here.
  # Persistence for ISO users can be added later if you want a dedicated persistence device.
}
