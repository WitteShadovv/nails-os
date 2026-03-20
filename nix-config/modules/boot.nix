{ config, lib, ... }:
let
  bootFs = config.fileSystems."/boot" or null;
  isVfat = bootFs != null && (bootFs.fsType or "") == "vfat";
in {
  # FAT32 /boot (EFI): restrict permissions via mount options.
  fileSystems."/boot".options = lib.mkIf isVfat (lib.mkAfter [ "umask=0077" ]);
}
