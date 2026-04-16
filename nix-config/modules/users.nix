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
        # UID 399: chosen from the system UID range (< 500) to ensure the
        # clearnet user is a system account.  This dedicated user runs the
        # Unsafe Browser with restricted network access (ports 80/443 only,
        # bypassing Tor) for captive-portal login.  The matching GID is set
        # below in groups.clearnet.
        uid = 399;
        group = "clearnet";
      };
    };

    groups.clearnet = { gid = 399; };
  };
}
