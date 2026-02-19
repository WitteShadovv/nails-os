{ lib, ... }: {
  boot.initrd.systemd.enable = true;

  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" "size=4G" ];
    };
    "/persist" = {
      device = lib.mkDefault "/dev/mapper/persist";
      fsType = "ext4";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/persist/nix";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/persist" ];
      neededForBoot = true;
    };
  };

  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      "/etc/nixos" # NixOS conf
      "/var/lib/nixos" # Important nixos files like uid/gid map
      "/var/lib/AccountsService" # Needed to show profile picture of user
      "/var/lib/systemd/backlight" # Used for screen brightness
      "/var/lib/systemd/rfkill" # Used for bluetooth state
      "/var/lib/bluetooth" # Persist bluetooth connections
      {
        directory = "/home/amnesia";
        user = "amnesia";
        group = "users";
        mode = "u=rwx,g=,o=";
      }
    ];

    files = [
      "/etc/machine-id" # Needed for various things like systemd logs
      "/etc/adjtime" # Hardware clock offset
    ];
  };
}
