{ pkgs, lib, ... }:

{
  config = {
    assertions = [
      {
        assertion = pkgs ? obfs4;
        message =
          "obfs4 is required for Tor censorship circumvention (pluggable transports) but is not available in nixpkgs. This would silently break censorship circumvention.";
      }
      {
        assertion = pkgs ? snowflake;
        message =
          "snowflake is required for Tor censorship circumvention (pluggable transports) but is not available in nixpkgs. This would silently break censorship circumvention.";
      }
    ];

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
        obfs4
        snowflake
      ]
      ++ lib.optional (pkgs.kdePackages ? kleopatra) pkgs.kdePackages.kleopatra
      ++ lib.optional (pkgs ? veracrypt) pkgs.veracrypt
      ++ lib.optional (pkgs ? mat2) pkgs.mat2
      ++ lib.optional (pkgs ? onioncircuits) pkgs.onioncircuits;
  };
}
