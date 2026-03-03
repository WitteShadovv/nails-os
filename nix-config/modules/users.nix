{ lib, ... }: {
  imports = lib.optional (builtins.pathExists ./secrets.nix) ./secrets.nix;

  users = {
    # Avoid eval failures before the installer writes secrets.nix.
    allowNoPasswordLogin = lib.mkDefault (!builtins.pathExists ./secrets.nix);

    users = {
      amnesia = {
        isNormalUser = true;
        # Fixed UID/GID so that the home-directory ownership set by the
        # Calamares installer (chown uid:gid /persist/home/amnesia) stays
        # valid across reboots.  Without a pinned UID, NixOS may allocate a
        # different UID on first boot before the /var/lib/nixos uid-map is
        # restored by impermanence, leaving /home/amnesia owned by a stale id.
        uid = 1000;
        description = "Amnesia";
        home = "/home/amnesia";
        extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
      };

      clearnet = {
        isSystemUser = true;
        uid = 399;
        group = "clearnet";
      };
    };

    groups.clearnet = { gid = 399; };
  };
}
