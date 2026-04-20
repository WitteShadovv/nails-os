{ config, lib, ... }:
{
  options.nailsOs.shellHistory = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shell history for all shells (bash, zsh, fish).";
    };
  };

  config = lib.mkIf (!config.nailsOs.shellHistory.enable) {
    # Defense layer 1: System-wide environment variables.
    # HISTFILE is intentionally NOT set here — setting it to /dev/null is
    # actively harmful: bash will delete the device node when it truncates an
    # oversized history file (GNU bash bug, Jan 2015), and zsh produces locking
    # errors when it tries to acquire a file lock on a character device.
    # The correct approach is to *unset* HISTFILE in shell init (layers 2 & 3).
    # HISTSIZE/HISTFILESIZE/SAVEHIST=0 here add a first-pass defence for any
    # process that inherits the environment before shell init runs.
    environment.variables = {
      HISTSIZE = "0";
      HISTFILESIZE = "0";
      HISTCONTROL = "ignoreboth";
      SAVEHIST = "0";
    };

    # Defense layer 2: Shell profile scripts via environment.etc.
    # These run early in every interactive login shell (before user dotfiles).
    environment.etc = {
      # Bash: sourced by /etc/profile on every login shell.
      "profile.d/nails-disable-history.sh" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable bash history (layer 2)
          # Unset instead of pointing to /dev/null — no file is ever opened.
          unset HISTFILE
          export HISTSIZE=0
          export HISTFILESIZE=0
          set +o history 2>/dev/null || true
        '';
      };

      # Zsh: sourced via /etc/zshrc.d/ for every interactive zsh.
      # 00- prefix guarantees execution before any user zshrc.
      "zshrc.d/00-nails-disable-history.zsh" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable zsh history (layer 2)
          # zsh mailing list (2011): setting HISTFILE=/dev/null triggers locking
          # errors and still wastes cycles saving to the bit-bucket. Unset it.
          unset HISTFILE
          HISTSIZE=0
          SAVEHIST=0
          setopt NO_SHARE_HISTORY
          setopt NO_APPEND_HISTORY
        '';
      };

      # Fish: sourced via /etc/fish/conf.d/ for every interactive fish session.
      # 00- prefix guarantees execution before user conf.d/ files.
      "fish/conf.d/00-nails-disable-history.fish" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable fish history (layer 2)
          # Empty string maps to no backing file — history stays in RAM only
          # and is discarded when the session ends (fish docs: "history.html").
          set -gx fish_history ""
        '';
      };
    };

    # Defense layer 3: Shell program configuration via mkBefore.
    # Runs inside every interactive shell instance, before any user-defined
    # init.  Catches subshells and shells started outside the login chain
    # (e.g. terminals launched from a GUI without a login shell).
    programs = {
      bash.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable bash history (layer 3)
        unset HISTFILE
        HISTSIZE=0
        HISTFILESIZE=0
        set +o history
      '';

      zsh.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable zsh history (layer 3)
        unset HISTFILE
        HISTSIZE=0
        SAVEHIST=0
        setopt NO_SHARE_HISTORY
        setopt NO_APPEND_HISTORY
      '';

      fish.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable fish history (layer 3)
        set -gx fish_history ""
      '';
    };
  };
}
