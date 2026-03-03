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
      # Do not let NetworkManager overwrite resolv.conf with DHCP-provided
      # nameservers.  All DNS is handled by Tor's DNSPort; see tor.nix.
      dns = "none";
    };
    dhcpcd.enable = false;
    enableIPv6 = false;
    # Point the system resolver at localhost.  App DNS queries to port 53
    # are redirected by nftables to Tor's DNSPort on 8853.  Tor's own
    # process (and child pluggable-transport processes such as
    # snowflake-client) bypass that DNAT rule via the tor-uid exemption and
    # reach Tor's DNSPort directly on port 53.
    nameservers = [ "127.0.0.1" ];
  };
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

}
