{ lib, ... }: {
  # Stub — replaced by the Calamares installer with real UUIDs and LUKS config.
  # This file is intentionally at the flake root to match the conventional
  # /etc/nixos/hardware-configuration.nix path expected by external tooling.
  # Declares minimal fileSystems so the flake evaluates cleanly before install.
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    # Let the kernel size tmpfs relative to available RAM. A fixed 4G cap on a
    # no-swap system makes low-memory machines hit the OOM killer before tmpfs
    # itself back-pressures writes.
    options = [ "mode=755" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BOOT";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
