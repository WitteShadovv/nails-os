{ config, lib, pkgs, ... }: {
  # Replace with output of `nixos-generate-config` for your hardware.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BOOT";
    fsType = "vfat";
  };
}
