_: {
  # systemd initrd is required for impermanence's pivot-root behaviour.
  boot.initrd.systemd.enable = true;

  # The actual fileSystems (tmpfs /, /persist, /nix bind) are declared in
  # hardware-configuration.nix by the installer, which also supplies the real
  # LUKS UUID.  We only declare the persistence binds here.

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
