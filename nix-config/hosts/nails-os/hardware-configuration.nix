{ lib, ... }: {
  # Stub — replaced by the Calamares installer with real UUIDs and LUKS config.
  # Declares minimal fileSystems so the flake evaluates cleanly before install.
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" "size=4G" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BOOT";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
