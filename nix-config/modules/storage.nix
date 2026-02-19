{ lib, ... }: {
  boot.initrd.luks.devices = {
    persist = {
      device = lib.mkDefault "/dev/disk/by-uuid/CHANGE-ME-PERSIST";
      preLVM = true;
    };
  };
}
