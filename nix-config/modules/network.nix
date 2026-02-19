_: {
  networking = {
    networkmanager = {
      enable = true;
      # Prevent DHCP hostname leaks and randomize MAC addresses by default.
      settings = {
        main = { "hostname-mode" = "none"; };
        device = { "wifi.scan-rand-mac-address" = "yes"; };
        connection = {
          "wifi.cloned-mac-address" = "random";
          "ethernet.cloned-mac-address" = "random";
        };
      };
    };
    dhcpcd.enable = false;
    enableIPv6 = false;
    # Force local DNS usage; all DNS will be redirected to Tor's DNSPort.
    nameservers = [ "127.0.0.1" ];
  };
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

}
