{ pkgs, ... }:

let
  welcomeScript = pkgs.writeShellScript "nails-welcome" ''
        FLAG="/persist/.nails-welcome-done"

        # Only show on first boot after installation.
        if [ -f "$FLAG" ]; then
          exit 0
        fi

        ${pkgs.zenity}/bin/zenity --info \
          --title="Welcome to NAILS OS" \
          --width=560 \
          --height=480 \
          --text="<big><b>Welcome to NAILS OS</b></big>\n\n\
    <b>🔒 Network mode</b>\n\
    Your login account is <tt>amnesia</tt>. If you installed in Tor mode, \
    TCP traffic is transparently routed through Tor and DNS is resolved \
    through Tor. If you installed in Direct mode, traffic goes to the \
    clearnet and the Tor-routing and Tor-DNS protections described above do \
    not apply.\n\n\
    <b>🧹 Impermanence</b>\n\
    NAILS OS runs from a fresh tmpfs on every boot. Most of the system is \
    wiped when you shut down. In the default selective-persistence mode, only \
    these locations persist:\n\
      • <tt>Documents, Downloads, Music, Pictures, Videos, Desktop</tt>\n\
      • <tt>~/.ssh</tt>, <tt>~/.gnupg</tt>, GNOME settings, keyring\n\
    If you chose full home persistence during installation, all of \
    <tt>/home/amnesia</tt> persists instead. Everything else (browser history, \
    cache, temp files outside the persisted home) is gone on reboot.\n\n\
    <b>🌐 Unsafe Browser</b>\n\
    The \"Unsafe Browser\" bypasses Tor for captive-portal login only \
    (e.g. hotel/airport WiFi). <b>Never use it for private browsing.</b>\n\n\
    <b>📦 Installed applications</b>\n\
      • <b>Tor Browser</b> — anonymous web browsing\n\
      • <b>Thunderbird</b> — email\n\
      • <b>KeePassXC</b> — password manager\n\
      • <b>OnionShare</b> — secure file sharing\n\
      • <b>LibreOffice</b> — documents\n\
      • <b>GIMP / Inkscape</b> — image editing\n\
    Find all apps in the Activities menu (top-left corner).\n\n\
    <b>⚡ Security tips</b>\n\
      • Use Tor Browser whenever you want Tor-routed browsing\n\
      • Shell history is disabled by default\n\
      • Disk encryption protects your persisted data\n\
      • Onion Circuits is useful only when the system is in Tor mode\n\
      • Never reveal personal information over Tor"

        # Mark as shown so it won't appear again.
        mkdir -p "$(dirname "$FLAG")"
        touch "$FLAG"
  '';
in
{
  config = {
    environment.systemPackages = [ pkgs.zenity ];

    # XDG autostart entry for the welcome dialog.
    environment.etc."xdg/autostart/nails-welcome.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=NAILS OS Welcome
      Exec=${welcomeScript}
      NoDisplay=true
      X-GNOME-Autostart-enabled=true
    '';
  };
}
