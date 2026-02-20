{ config, lib, ... }:
let bootFs = config.fileSystems."/boot" or null;
in {
  fileSystems."/boot".options =
    lib.mkIf (bootFs != null && (bootFs.fsType or "") == "vfat")
    (lib.mkAfter [ "umask=0077" ]);
}
