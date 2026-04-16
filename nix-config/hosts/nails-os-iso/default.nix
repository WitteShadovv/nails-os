{ pkgs, lib, modulesPath, ... }:
let
  # ---------------------------------------------------------------------------
  # Our Calamares extensions (module + branding + config), built as a
  # derivation so everything lives in the Nix store (immutable, no /etc magic).
  # ---------------------------------------------------------------------------
  nailsCalamaresExtensions = pkgs.stdenv.mkDerivation {
    pname = "nails-os-calamares-extensions";
    version = "1";
    src = ./calamares;

    installPhase = ''
      runHook preInstall

      # Python exec module  →  $out/lib/calamares/modules/nails-os/
      mkdir -p $out/lib/calamares/modules/nails-os
      cp -r modules/nails-os/. $out/lib/calamares/modules/nails-os/

      # Custom viewmodules  →  $out/lib/calamares/modules/<name>/
      mkdir -p $out/lib/calamares/modules/history-config
      cp -r modules/history-config/. $out/lib/calamares/modules/history-config/

      mkdir -p $out/lib/calamares/modules/home-persistence-config
      cp -r modules/home-persistence-config/. $out/lib/calamares/modules/home-persistence-config/

      # Branding  →  $out/share/calamares/branding/nails-os/
      mkdir -p $out/share/calamares/branding/nails-os
      cp -r branding/nails-os/. $out/share/calamares/branding/nails-os/

      # Icon  →  hicolor theme so desktop files can reference Icon=nails-os
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp branding/nails-os/logo.png $out/share/icons/hicolor/256x256/apps/nails-os.png

      # Config  →  $out/etc/calamares/{settings.conf,modules/}
      mkdir -p $out/etc/calamares/modules
      cp config/settings.conf  $out/etc/calamares/settings.conf
      cp config/modules/*.conf $out/etc/calamares/modules/

      # Bake the upstream extensions store path and our own store path into
      # settings.conf so Calamares can find both module trees.
      substituteInPlace $out/etc/calamares/settings.conf \
        --replace-fail "@calamares_nixos_extensions@" \
          "${pkgs.calamares-nixos-extensions}" \
        --replace-fail "@out@" "$out"

      runHook postInstall
    '';
  };

  # Upstream Calamares extensions — needed in the launcher to set XDG_CONFIG_DIRS.
  upstExt = pkgs.calamares-nixos-extensions;

  # Launcher script: detects EFI vs BIOS boot mode and copies the correct
  # partition.conf into a tmpfs config dir before handing off to Calamares.
  # XDG_CONFIG_DIRS is set explicitly so Calamares finds our settings.conf
  # and the mode-appropriate partition.conf.
  calamaresLauncher = pkgs.writeShellScript "calamares-launch" ''
    uid=$(id -u)
    runtime_dir="/run/user/$uid"
    wayland_sock="''${WAYLAND_DISPLAY:-wayland-0}"
    chmod o+x "$runtime_dir" 2>/dev/null || true

    # Build a writable config directory in tmpfs so we can inject the correct
    # partition.conf for this boot mode.  Calamares searches XDG_CONFIG_DIRS
    # for calamares/settings.conf and calamares/modules/*.conf.
    cfg_dir="/run/calamares-cfg-$$"
    mkdir -p "$cfg_dir/calamares/modules"
    cp ${nailsCalamaresExtensions}/etc/calamares/settings.conf \
       "$cfg_dir/calamares/"
    cp ${nailsCalamaresExtensions}/etc/calamares/modules/*.conf \
       "$cfg_dir/calamares/modules/"

    # Select partition layout based on boot mode.
    # /sys/firmware/efi is present only when booted via UEFI firmware.
    if [ -d /sys/firmware/efi ]; then
      cp ${nailsCalamaresExtensions}/etc/calamares/modules/partition-efi.conf \
         "$cfg_dir/calamares/modules/partition.conf"
    else
      cp ${nailsCalamaresExtensions}/etc/calamares/modules/partition-bios.conf \
         "$cfg_dir/calamares/modules/partition.conf"
    fi

    exec sudo \
      WAYLAND_DISPLAY="$wayland_sock" \
      XDG_RUNTIME_DIR="$runtime_dir" \
      XDG_SESSION_TYPE="wayland" \
      QT_QPA_PLATFORM="wayland" \
      XDG_CONFIG_DIRS="$cfg_dir:${upstExt}/etc" \
      calamares
  '';

in {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
    ../../modules/base.nix
    ../../modules/security.nix
    ../../modules/packages.nix
    ../../modules/users.nix
    ../../modules/home.nix
  ];

  # ---------------------------------------------------------------------------
  # ISO image settings
  # ---------------------------------------------------------------------------
  image.fileName = "nails-os-installer.iso";
  isoImage = {
    edition = lib.mkForce "nails-os";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  networking.hostName = "nails-installer";

  # Forward kernel messages to serial so we can observe boot/hang in VMs.
  boot.kernelParams = [ "console=ttyS0,115200" "console=tty1" ];

  # Disable nix channel initialisation — we are flake-based and the channel
  # setup produces spurious symlink errors on the live ISO.
  system.installer.channel.enable = false;

  # ---------------------------------------------------------------------------
  # Make the NAILS OS flake available at /etc/nixos for nixos-install.
  # We copy it at boot into the writable tmpfs /etc instead of using
  # environment.etc, which would create a read-only store symlink that
  # clone-config.nix then cannot write configuration.nix into.
  # ---------------------------------------------------------------------------
  boot.postBootCommands = lib.mkAfter ''
    if ! [ -e /etc/nixos/flake.nix ]; then
      cp -aL ${../..}/. /etc/nixos
      chmod -R u+w /etc/nixos
    fi
  '';

  # ---------------------------------------------------------------------------
  # Replace pkgs.calamares-nixos with our wrapper via overlay so that the
  # upstream autostart .desktop item (created by installation-cd-graphical-
  # calamares.nix) automatically points at our wrapped binary.
  # ---------------------------------------------------------------------------
  nixpkgs.overlays = [
    (_final: prev: {
      # We must wrap the raw calamares ELF (prev.calamares) directly rather than
      # layering on top of prev.calamares-nixos.  The upstream calamares-nixos
      # wrapper hard-codes --prefix XDG_CONFIG_DIRS with the upstream extensions
      # path; since --prefix *prepends*, any outer wrapper that also uses
      # --prefix ends up second in the colon list.  Calamares picks the first
      # settings.conf it finds via XDG_CONFIG_DIRS, so the upstream one always
      # wins unless we take full ownership of the variable.
      #
      # Strategy: set XDG_CONFIG_DIRS to exactly "${ext}/etc:${upstream-ext}/etc"
      # so our settings.conf is found first, then fall back to upstream modules.
      # XDG_DATA_DIRS is additive (both sets of QML/branding assets are needed),
      # so we keep --prefix there.
      calamares-nixos = let
        ext = nailsCalamaresExtensions;
        upstExt = prev.calamares-nixos-extensions;
        rawBin = "${prev.calamares}/bin/calamares";
      in prev.runCommand "calamares-nails-wrapped" {
        nativeBuildInputs = [ prev.makeWrapper ];
      } ''
        mkdir -p $out/bin
        for i in $(ls ${prev.calamares-nixos}); do
          if [ "$i" != "bin" ]; then
            ln -s ${prev.calamares-nixos}/$i $out/$i
          fi
        done
        makeWrapper ${rawBin} $out/bin/calamares \
          --prefix XDG_DATA_DIRS   : "${upstExt}/share" \
          --prefix XDG_DATA_DIRS   : "${ext}/share" \
          --prefix XDG_CONFIG_DIRS : "${ext}/etc" \
          --add-flags "--xdg-config"
      '';
    })
  ];

  # Extra runtime tools used by our Python install module.
  # Also include our extensions package so the nails-os icon is in the
  # system icon search path (XDG_DATA_DIRS / icon theme).
  environment.systemPackages = with pkgs; [
    openssl
    util-linux
    nailsCalamaresExtensions
  ];

  # ---------------------------------------------------------------------------
  # Calamares launcher script + desktop file overrides.
  #
  # Problem: pkexec core-dumps in this Wayland+VirtualBox environment.
  # Falling back to "sudo -E" also fails because root cannot traverse
  # /run/user/<uid>/ (mode 0700) to reach the Wayland socket.
  #
  # Solution:
  #   • Install a small launcher script at /etc/calamares-launch that:
  #       1. chmod o+x /run/user/<uid> — grants root traverse access to the
  #          runtime dir (the socket itself is already world-readable: srwxr-xr-x)
  #       2. Passes the required display env vars explicitly to sudo.
  #   • Override the .desktop files (autostart + applications) to invoke the
  #     script instead of pkexec.
  #   • /etc/xdg is searched before /run/current-system/sw/etc/xdg so the
  #     overrides win over the upstream read-only store symlinks.
  # ---------------------------------------------------------------------------
  environment.etc = {
    "calamares-launch" = {
      mode = "0755";
      source = calamaresLauncher;
    };
    "xdg/autostart/calamares.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Install NAILS OS
      GenericName=System Installer
      Keywords=calamares;system;installer;
      Exec=/etc/calamares-launch
      Comment=Install NAILS OS to disk
      Icon=nails-os
      Terminal=false
      StartupNotify=true
      Categories=Qt;System;
      X-KDE-autostart-phase=2
    '';
    "xdg/applications/calamares.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=Install NAILS OS
      GenericName=System Installer
      Keywords=calamares;system;installer;
      Exec=/etc/calamares-launch
      Comment=Install NAILS OS to disk
      Icon=nails-os
      Terminal=false
      StartupNotify=true
      Categories=Qt;System;
    '';
  };
}
