{ lib, ... }: {
  imports = lib.optional (builtins.pathExists ./secrets.nix) ./secrets.nix;

  users = {
    # Avoid eval failures before the installer writes secrets.nix.
    allowNoPasswordLogin = lib.mkDefault (!builtins.pathExists ./secrets.nix);

    users = {
      amnesia = {
        isNormalUser = true;
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
