{ lib, config, ... }:
{
  config = lib.mkMerge [
    {
      networking = {
        networkmanager = {
          enable = true;
          # Prevent DHCP hostname leaks and randomize MAC addresses by default.
          settings = {
            main = {
              "hostname-mode" = "none";
            };
            device = {
              "wifi.scan-rand-mac-address" = "yes";
            };
            connection = {
              "wifi.cloned-mac-address" = "random";
              "ethernet.cloned-mac-address" = "random";
            };
          };
        };
        dhcpcd.enable = false;
        enableIPv6 = false;
      };

      boot.kernel.sysctl = {
        "net.ipv6.conf.all.disable_ipv6" = 1;
        "net.ipv6.conf.default.disable_ipv6" = 1;
      };
    }

    (lib.mkIf config.nailsOs.tor.enable {
      networking = {
        networkmanager = {
          # Don't let NM touch resolv.conf — we point it at Tor's DNSPort (53)
          # so all app DNS goes through Tor. The tor uid's DNS is DNAT'd by
          # nftables to a real public resolver (9.9.9.9) so PTs like snowflake
          # can resolve the broker hostname before circuits exist.
          dns = "none";
        };
        nameservers = [ "127.0.0.1" ];
      };
    })
  ];
}
