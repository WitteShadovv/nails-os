{ lib, ... }: {
  imports = [
    ../../hardware-configuration.nix
    # Written by the Calamares installer with the user-chosen hostname.
    # Guarded by pathExists so the flake evaluates cleanly before installation.
  ] ++ lib.optional (builtins.pathExists ./hostname.nix) ./hostname.nix
    # Written by the Calamares installer with the user-chosen network mode.
    # Guarded by pathExists so the flake evaluates cleanly before installation.
    ++ lib.optional (builtins.pathExists ./network-mode.nix) ./network-mode.nix
    # Written by the Calamares installer with timezone/locale/keyboard settings.
    # locale.nix always exists (stub provides UTC/us defaults).
    ++ [ ./locale.nix ] ++ [
      ../../modules/base.nix
      ../../modules/network.nix
      ../../modules/security.nix
      ../../modules/boot.nix
      ../../modules/storage.nix
      ../../modules/impermanence.nix
      ../../modules/tor.nix
      ../../modules/packages.nix
      ../../modules/users.nix
      ../../modules/home.nix
    ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  # Do not allow mutable users; set passwords via declarative config if needed.
  users.mutableUsers = false;

  system.stateVersion = "25.11";
}
