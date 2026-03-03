{ config, pkgs, lib, ... }:
let
  torTransPort = 9040;
  torDNSPort = 8853;
  torSocksPort = 9050;
  torUid = config.users.users.tor.uid;
  clearnetUid = config.users.users.clearnet.uid;
  rfc1918 = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }";
  transportPlugins = lib.flatten [
    (lib.optional (pkgs ? obfs4) "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy")
    (lib.optional (pkgs ? snowflake)
      "snowflake exec ${pkgs.snowflake}/bin/snowflake-client")
  ];
  unsafeBrowser = pkgs.writeShellScript "unsafe-browser" ''
    exec ${pkgs.util-linux}/bin/runuser -u clearnet -- ${pkgs.firefox}/bin/firefox "$@"
  '';
in {
  services.tor.enable = true;
  services.tor.settings = {
    SOCKSPort = [{
      port = torSocksPort;
      IsolateSOCKSAuth = true;
    }];
    TransPort = torTransPort;
    # Bind DNSPort on two addresses:
    #   - 8853: receives redirected app DNS via the nftables DNAT rule
    #   - 53:   receives direct DNS from the Tor process itself (and its
    #           child pluggable-transport processes such as snowflake-client)
    #           which bypass the DNAT rule because they run as the tor uid.
    DNSPort = [ { port = torDNSPort; } { port = 53; } ];
    AutomapHostsOnResolve = true;
    VirtualAddrNetworkIPv4 = "10.192.0.0/10";
    # Pluggable transports are available for when bridges are configured.
    ClientTransportPlugin = transportPlugins;
    # Use Snowflake by default to evade blocking.
    UseBridges = true;
    Bridge = [ "snowflake 192.0.2.3:1" ];
  };

  # Transparent proxying to Tor with RFC1918 exceptions and DNS isolation.
  networking = {
    firewall.enable = false;
    nftables = {
      enable = true;
      ruleset = ''
        define tor_uid = ${toString torUid}
        define clearnet_uid = ${toString clearnetUid}

        table ip nat {
          chain output {
            type nat hook output priority 0; policy accept;

            meta skuid $tor_uid return
            meta skuid $clearnet_uid return

            udp dport 53 dnat to 127.0.0.1:${toString torDNSPort}

            ip daddr 127.0.0.0/8 return
            ip daddr ${rfc1918} return

            ip protocol tcp dnat to 127.0.0.1:${toString torTransPort}
          }
        }

        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;
            ct state established,related accept
            iifname "lo" accept
            ip protocol icmp accept
            udp sport 67 udp dport 68 accept
          }

          chain output {
            type filter hook output priority 0; policy drop;
            ct state established,related accept
            oifname "lo" accept

            meta skuid $tor_uid accept

            # Unsafe Browser (clearnet user) gets limited direct access for captive portals.
            meta skuid $clearnet_uid udp dport 53 accept
            meta skuid $clearnet_uid ip daddr ${rfc1918} accept
            meta skuid $clearnet_uid tcp dport { 80, 443 } accept
            meta skuid $clearnet_uid drop

            ip daddr ${rfc1918} tcp dport 53 drop
            ip daddr ${rfc1918} udp dport 53 drop
            ip daddr ${rfc1918} accept

            udp dport != 53 drop
            accept
          }
        }
      '';
    };
  };

  # Setuid wrapper for the Unsafe Browser (captive portal use only).
  security.wrappers.unsafe-browser = {
    source = unsafeBrowser;
    owner = "root";
    group = "root";
    setuid = true;
  };

  environment.etc."xdg/applications/unsafe-browser.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Unsafe Browser
    Exec=unsafe-browser
    Icon=firefox
    Categories=Network;WebBrowser;
    Terminal=false
  '';
}
