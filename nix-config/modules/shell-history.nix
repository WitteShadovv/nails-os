{ config, lib, ... }: {
  options.nailsOs.shellHistory = {
    disable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable shell history for all shells (bash, zsh, fish).";
    };
  };

  config = lib.mkIf config.nailsOs.shellHistory.disable {
    # Defense layer 1: Environment variables
    # These are set system-wide and apply to all shells.
    environment.variables = {
      HISTFILE = "/dev/null";
      HISTSIZE = "0";
      HISTFILESIZE = "0";
      HISTCONTROL = "ignoreboth";
      SAVEHIST = "0";
    };

    # Defense layer 2: Shell profile scripts via environment.etc
    environment.etc = {
      # Bash profile script in /etc/profile.d/
      "profile.d/nails-disable-history.sh" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable bash history (defense layer 2)
          unset HISTFILE
          export HISTSIZE=0
          export HISTFILESIZE=0
          set +o history 2>/dev/null || true
        '';
      };

      # Zsh profile script in /etc/zshrc.d/
      # The 00- prefix ensures it runs before other zsh configs.
      "zshrc.d/00-nails-disable-history.zsh" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable zsh history (defense layer 2)
          unset HISTFILE
          HISTSIZE=0
          SAVEHIST=0
          setopt NO_SHARE_HISTORY
          setopt NO_APPEND_HISTORY
        '';
      };

      # Fish configuration in /etc/fish/conf.d/
      # The 00- prefix ensures it runs before other fish configs.
      "fish/conf.d/00-nails-disable-history.fish" = {
        mode = "0444";
        text = ''
          # NAILS OS: Disable fish history (defense layer 2)
          set -gx fish_history ""
        '';
      };
    };

    # Defense layer 3: Activation script to create symlinks
    # Runs after user/group creation to ensure home directories exist.
    system.activationScripts.disableShellHistory =
      lib.stringAfter [ "users" "groups" ] ''
        # /etc/skel for new users
        mkdir -p /etc/skel/.local/share/fish
        ln -sf /dev/null /etc/skel/.bash_history
        ln -sf /dev/null /etc/skel/.zsh_history
        ln -sf /dev/null /etc/skel/.local/share/fish/fish_history

        # Root user
        rm -f /root/.bash_history /root/.zsh_history 2>/dev/null || true
        rm -rf /root/.local/share/fish/fish_history 2>/dev/null || true
        ln -sf /dev/null /root/.bash_history
        ln -sf /dev/null /root/.zsh_history
        mkdir -p /root/.local/share/fish
        ln -sf /dev/null /root/.local/share/fish/fish_history

        # Existing home directories
        for home in /home/*; do
          if [ -d "$home" ]; then
            rm -f "$home/.bash_history" "$home/.zsh_history" 2>/dev/null || true
            rm -rf "$home/.local/share/fish/fish_history" 2>/dev/null || true
            ln -sf /dev/null "$home/.bash_history"
            ln -sf /dev/null "$home/.zsh_history"
            mkdir -p "$home/.local/share/fish"
            ln -sf /dev/null "$home/.local/share/fish/fish_history"
          fi
        done
      '';

    # Defense layer 4: Shell program configuration
    # mkBefore ensures this runs before any user-defined shell init.
    programs = {
      bash.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable bash history (defense layer 4)
        unset HISTFILE
        HISTSIZE=0
        HISTFILESIZE=0
        set +o history
      '';

      zsh.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable zsh history (defense layer 4)
        unset HISTFILE
        HISTSIZE=0
        SAVEHIST=0
        setopt NO_SHARE_HISTORY
        setopt NO_APPEND_HISTORY
      '';

      fish.interactiveShellInit = lib.mkBefore ''
        # NAILS OS: Disable fish history (defense layer 4)
        set -gx fish_history ""
      '';
    };
  };
}
