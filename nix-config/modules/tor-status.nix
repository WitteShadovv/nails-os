{ pkgs, ... }:

# Ensure onioncircuits is always installed (not conditional) and auto-starts
# on login so users can visually verify Tor circuit status at a glance.
{
  environment.systemPackages = [ pkgs.onioncircuits ];

  # GNOME autostart entry — launches minimised so it's available but not
  # intrusive.  The user can find it in the system tray / app list.
  environment.etc."xdg/autostart/onioncircuits.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Onion Circuits
    Comment=Monitor active Tor circuits
    Exec=${pkgs.onioncircuits}/bin/onioncircuits
    Icon=onioncircuits
    NoDisplay=true
    X-GNOME-Autostart-enabled=true
    X-GNOME-Autostart-Delay=5
  '';
}
