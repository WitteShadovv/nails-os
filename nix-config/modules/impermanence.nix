{ config, ... }:

let
  inherit (config.nailsOs.homePersistence) selective;
  user = "amnesia";

  # Helper: persist a subdirectory of /home/${user} with restrictive permissions.
  homeDir = subdir: {
    directory = "/home/${user}/${subdir}";
    inherit user;
    group = "users";
    mode = "u=rwx,g=,o="; # 700 — owner only
  };

  # Curated set: user content + low-risk functional state only.
  # Deliberately excludes recently-used.xbel, gvfs-metadata, tracker3,
  # zeitgeist, cache/, and full browser profiles — those accumulate forensic
  # artefacts and are safe to wipe on every reboot.
  selectiveDirs = map homeDir [
    # XDG user-content directories
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    "Desktop"
    # GNOME settings (theme, font, keyboard, wallpaper path — low privacy risk)
    ".config/dconf"
    # GNOME keyring — WiFi passwords and app credentials
    ".local/share/keyrings"
    # Cryptographic identities — functional and intentionally private
    ".ssh"
    ".gnupg"
  ];

  fullHome = [{
    directory = "/home/${user}";
    inherit user;
    group = "users";
    mode = "u=rwx,g=,o=";
  }];
in {
  imports = [ ./home-persistence.nix ];

  config = {
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
      ] ++ (if selective then selectiveDirs else fullHome);

      files = [
        "/etc/machine-id" # Needed for various things like systemd logs
      ];
    };
  };
}
