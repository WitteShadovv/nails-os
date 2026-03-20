{ pkgs, lib, ... }: {
  environment.systemPackages = with pkgs;
    [
      tor-browser
      thunderbird
      pidgin
      pidginPackages.pidgin-otr
      onionshare
      electrum
      keepassxc
      libreoffice-fresh
      gimp
      inkscape
      audacity
      simple-scan
      gnupg
      cryptsetup
      firefox
      wget
      curl
      openssh
      tesseract
      ffmpeg
      libnotify
    ] ++ lib.optional (pkgs.kdePackages ? kleopatra) pkgs.kdePackages.kleopatra
    ++ lib.optional (pkgs ? obfs4) pkgs.obfs4
    ++ lib.optional (pkgs ? snowflake) pkgs.snowflake
    ++ lib.optional (pkgs ? veracrypt) pkgs.veracrypt
    ++ lib.optional (pkgs ? mat2) pkgs.mat2
    ++ lib.optional (pkgs ? onioncircuits) pkgs.onioncircuits;
}
