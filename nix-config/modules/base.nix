{ pkgs, lib, ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "veracrypt" ];

  time.timeZone = "UTC";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
      "es_ES.UTF-8/UTF-8"
      "fr_FR.UTF-8/UTF-8"
      "ru_RU.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
      "ko_KR.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
    ];

    inputMethod = {
      enable = true;
      type = "ibus";
      ibus.engines = with pkgs; [
        ibus-engines.mozc
        ibus-engines.libpinyin
        ibus-engines.hangul
      ];
    };
  };

  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
    };
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };

  programs.dconf.enable = true;

  # Hostname is set per-host.

  # Keep the system minimal and explicit; add services in other modules.
}
