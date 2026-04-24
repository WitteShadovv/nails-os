{ lib, ... }:
{
  imports = [
    ../../hardware-configuration.nix
    # Written by the Calamares installer with the user-chosen hostname.
    # Guarded by pathExists so the flake evaluates cleanly before installation.
  ]
  ++ lib.optional (builtins.pathExists ./hostname.nix) ./hostname.nix
  # Written by the Calamares installer only when the user chose Direct mode.
  # Absent = default Tor configuration remains active. Guarded by pathExists.
  ++ lib.optional (builtins.pathExists ./network-mode.nix) ./network-mode.nix
  # Written by the Calamares installer with the user-chosen shell history mode.
  # Guarded by pathExists so the flake evaluates cleanly before installation.
  ++ lib.optional (builtins.pathExists ./shell-history-mode.nix) ./shell-history-mode.nix
  # Written by the Calamares installer when the user chose full home persistence.
  # Absent = selective mode (the default). Guarded by pathExists.
  ++ lib.optional (builtins.pathExists ./home-persistence-mode.nix) ./home-persistence-mode.nix
  # Written by the Calamares installer with timezone/locale/keyboard settings.
  # locale.nix and boot-mode.nix always exist (stubs provide safe defaults).
  ++ [
    ./locale.nix
    ./boot-mode.nix
  ]
  ++ [
    ../../modules/base.nix
    ../../modules/network.nix
    ../../modules/security.nix
    ../../modules/boot.nix
    ../../modules/impermanence.nix
    ../../modules/tor.nix
    ../../modules/tor-status.nix
    ../../modules/welcome.nix
    ../../modules/shell-history.nix
    ../../modules/packages.nix
    ../../modules/users.nix
    ../../modules/home.nix
  ];

  # Do not allow mutable users; set passwords via declarative config if needed.
  users.mutableUsers = false;

  system.stateVersion = "25.11";
}
