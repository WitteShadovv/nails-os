_: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/network.nix
    ../../modules/security.nix
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
