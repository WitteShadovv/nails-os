{ config, lib, ... }:
# Restrict FAT32 EFI partition permissions via mount options.
# The ESP path comes from boot-mode.nix (/boot/efi for EFI, unused for BIOS).
# We guard with mkIf so the fileSystems key is never created in BIOS mode
# (where systemd-boot is disabled and /boot is a bind mount, not vfat).
lib.mkIf config.boot.loader.systemd-boot.enable {
  fileSystems.${config.boot.loader.efi.efiSysMountPoint}.options = lib.mkAfter [ "umask=0077" ];
}
