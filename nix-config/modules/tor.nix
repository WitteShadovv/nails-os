{ config, pkgs, lib, ... }:
let
  torTransPort = 9040;
  torDNSPort = 8853;
  torUid = config.users.users.tor.uid;
  clearnetUid = config.users.users.clearnet.uid;
  rfc1918 = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }";

  # External DNS resolver used by the tor uid for PT bootstrap (e.g. snowflake
  # broker resolution) before any Tor circuit exists.  Quad9 is a non-logging,
  # DNSSEC-validating resolver operated by the Quad9 Foundation (Swiss non-profit).
  quad9 = "9.9.9.9";
  transportPlugins = [
    "obfs4 exec ${pkgs.obfs4}/bin/lyrebird"
    "snowflake exec ${pkgs.snowflake}/bin/client"
  ];
  # ---------------------------------------------------------------------------
  # Default bridges from Tor Browser's pt_config.json — the same set that
  # Tails and Tor Browser ship.  These are the Tor Project's official
  # "default bridges" maintained by the Anti-Censorship Team and explicitly
  # intended for embedding in client software.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Bridge maintenance guide
  # ---------------------------------------------------------------------------
  # WHERE:   https://bridges.torproject.org/ (select obfs4 or snowflake)
  #          or email bridges@torproject.org with "get transport obfs4" in body.
  # HOW:     Replace the bridge lines below with the new descriptors.  Each
  #          line is a single string in Tor's "Bridge" format.  For snowflake,
  #          update the structured attrs and the broker URL / fronts / ICE list.
  # WHEN:    Review at every NAILS OS release.  Replace sooner if Tor Browser
  #          ships a newer default set (check tor-browser-build.git
  #          projects/common/bridges_list.*) or if users report connection
  #          failures indicating bridges are blocked or offline.
  # LAST UPDATED: 2025-10-01 (from Tor Browser 14.x pt_config.json)
  # ---------------------------------------------------------------------------

  # obfs4 bridges (7) — most stable transport, simple TCP obfuscation.
  # Reachable in most networks; may be IP-blocked in China/Iran/Russia.
  obfs4Bridges = [
    "obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0"
    "obfs4 209.148.46.65:443 74FAD13168806246602538555B5521A0383A1875 cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw iat-mode=0"
    "obfs4 146.57.248.225:22 10A6CD36A537FCE513A322361547444B393989F0 cert=K1gDtDAIcUfeLqbstggjIw2rtgIKqdIhUlHp82XRqNSq/mtAjp1BIC9vHKJ2FAEpGssTPw iat-mode=0"
    "obfs4 45.145.95.6:27015 C5B7CD6946FF10C5B3E89691A7D3F2C122D2117C cert=TD7PbUO0/0k6xYHMPW3vJxICfkMZNdkRrb63Zhl5j9dW3iRGiCx0A7mPhe5T2EDzQ35+Zw iat-mode=0"
    "obfs4 51.222.13.177:80 5EDAC3B810E12B01F6FD8050D2FD3E277B289A08 cert=2uplIpLQ0q9+0qMFrK5pkaYRDOe460LL9WHBvatgkuRr/SL31wBOEupaMMJ6koRE6Ld0ew iat-mode=0"
    "obfs4 212.83.43.95:443 BFE712113A72899AD685764B211FACD30FF52C31 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=1"
    "obfs4 212.83.43.74:443 39562501228A4D5E27FCA4C0C81A01EE23AE3EE4 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=1"
  ];

  # Serialise a structured snowflake bridge descriptor into the one-line string
  # that Tor's Bridge directive expects.  Full parameters (url, fronts, ice,
  # utls-imitate) are required so that snowflake-client knows how to reach the
  # broker; without them it falls back to stale compiled-in defaults and exits
  # immediately after PT initialisation (the "died in state Completed" loop).
  mkSnowflakeBridge = { addr, fingerprint, url, fronts, ice
    , utlsImitate ? "hellorandomizedalpn", }:
    lib.concatStringsSep " " [
      "snowflake ${addr} ${fingerprint}"
      "fingerprint=${fingerprint}"
      "url=${url}"
      "fronts=${lib.concatStringsSep "," fronts}"
      "ice=${lib.concatStringsSep "," ice}"
      "utls-imitate=${utlsImitate}"
    ];

  # Snowflake bridges (2) — uses WebRTC + domain fronting via CDN77.
  # Works in heavily censored countries but depends on volunteer proxies
  # and a central broker; connection setup is slower than obfs4.
  # (Bug 41609, Oct 2025 — CDN77 broker with datapacket.com fronts.)
  commonBrokerUrl = "https://1098762253.rsc.cdn77.org/";
  commonFronts = [ "app.datapacket.com" "www.datapacket.com" ];
  commonIce = [
    "stun:stun.epygi.com:3478"
    "stun:stun.uls.co.za:3478"
    "stun:stun.voipgate.com:3478"
    "stun:stun.mixvoip.com:3478"
    "stun:stun.nextcloud.com:3478"
    "stun:stun.bethesda.net:3478"
    "stun:stun.nextcloud.com:443"
  ];
  snowflakeBridges = map mkSnowflakeBridge [
    {
      # snowflake-01
      addr = "192.0.2.3:80";
      fingerprint =
        "2B280B23E1107BB62ABFC40DDCC8824814F80A72"; # pragma: allowlist secret
      url = commonBrokerUrl;
      fronts = commonFronts;
      ice = commonIce;
    }
    {
      # snowflake-02 (separate capacity, same broker)
      addr = "192.0.2.4:80";
      fingerprint =
        "8838024498816A039FCBBAB14E6F40A0843051FA"; # pragma: allowlist secret
      url = commonBrokerUrl;
      fronts = commonFronts;
      ice = commonIce;
    }
  ];

  # All default bridges — obfs4 first (most stable), then snowflake.
  defaultBridges = obfs4Bridges ++ snowflakeBridges;
  unsafeBrowser = pkgs.writeShellScript "unsafe-browser" ''
    exec ${pkgs.util-linux}/bin/runuser -u clearnet -- ${pkgs.firefox}/bin/firefox "$@"
  '';
in {
  options.nailsOs.tor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable transparent Tor routing for all network traffic.
        When false, Tor is not started, nftables transparent proxy rules
        are not installed, and the Unsafe Browser wrapper is omitted.
      '';
    };

    useBridges = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use pluggable-transport bridges (obfs4 + Snowflake) for censorship
        circumvention.  The default bridge set matches Tor Browser / Tails.
        Set to false to connect directly to the Tor network, bypassing bridge
        negotiation entirely.
      '';
    };
  };

  config = lib.mkIf config.nailsOs.tor.enable {
    services = {
      # NTP is needed so Tor doesn't reject the consensus due to clock skew.
      # Note: timesyncd (UDP 123) is blocked by the nftables filter until Tor
      # has circuits.  In VirtualBox the guest-additions clock sync covers this;
      # on real hardware a Tails-style htpdate (HTTP Date headers through Tor)
      # would be needed as a future improvement.
      timesyncd.enable = true;

      tor = {
        enable = true;
        client.enable = true;
        settings = {
          TransPort = torTransPort;
          # App DNS queries to port 53 are DNAT'd by nftables to DNSPort on 8853.
          # The tor uid bypasses that DNAT rule and uses the DHCP resolver directly
          # (see network.nix), so PT children like snowflake-client can reach the
          # Snowflake broker before any Tor circuit exists.
          DNSPort = [ { port = torDNSPort; } { port = 53; } ];
          AutomapHostsOnResolve = true;
          VirtualAddrNetworkIPv4 = "10.192.0.0/10";

          # Tor 0.4.9.x has a known conflux regression that breaks circuit building
          # ("Failed to find node for hop #1", assertion failures).  Disable until
          # the upstream fix lands in a stable release.
          ConfluxEnabled = false;

          # Prevent Tor from starting in dormant mode after reboot — with a
          # transparent proxy there is no trigger to wake it, so circuits would
          # never be built.
          DormantCanceledByStartup = true;
          ClientTransportPlugin =
            lib.mkIf config.nailsOs.tor.useBridges transportPlugins;
          UseBridges = config.nailsOs.tor.useBridges;
          Bridge = lib.mkIf config.nailsOs.tor.useBridges defaultBridges;
        };
      };
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
              type nat hook output priority dstnat; policy accept;

              # Tor UID: redirect DNS to a real resolver so PTs (snowflake)
              # can resolve the broker before any Tor circuit exists.
              # Other tor traffic (bridge connections) goes directly.
              meta skuid $tor_uid udp dport 53 dnat to ${quad9}:53
              meta skuid $tor_uid return

              meta skuid $clearnet_uid return

              # App DNS: resolv.conf points to 127.0.0.1 (Tor's DNSPort 53),
              # so most DNS arrives there directly.  This catch-all also
              # redirects any hardcoded DNS to prevent leaks.
              udp dport 53 dnat to 127.0.0.1:${toString torDNSPort}

              ip daddr 127.0.0.0/8 return

              # .onion virtual IPs (AutomapHostsOnResolve) live inside
              # 10.192.0.0/10 which overlaps with 10.0.0.0/8 in rfc1918.
              # Redirect them to TransPort BEFORE the RFC1918 exemption.
              ip daddr 10.192.0.0/10 ip protocol tcp dnat to 127.0.0.1:${
                toString torTransPort
              }

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
  };
}
