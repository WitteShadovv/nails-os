# Default stub — overwritten by the Calamares installer with the user's
# chosen timezone, locale, and keyboard layout.
# This file must exist so the flake evaluates cleanly before installation.
_: {
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
