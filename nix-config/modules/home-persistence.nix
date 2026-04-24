{ lib, ... }:
{
  options.nailsOs.homePersistence = {
    selective = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true (the default), persist only a curated set of user-content
        and low-risk functional directories instead of the entire home.

        Directories that are always left on tmpfs in selective mode (wiped
        each reboot):
          ~/.local/share/recently-used.xbel  — recent-files list
          ~/.local/share/gvfs-metadata/       — file-manager metadata
          ~/.local/share/tracker3/            — file-search index
          ~/.local/share/zeitgeist/           — activity log
          ~/.cache/                           — app caches & thumbnails
          Full browser profiles               — ~/.mozilla, ~/.config/chromium

        When false, the entire /home/amnesia directory is persisted (convenient
        but may accumulate forensic artifacts across reboots).
      '';
    };
  };
}
