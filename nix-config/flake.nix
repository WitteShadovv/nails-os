{
  description = "NAILS OS (TAILS-like) NixOS with impermanence";

  inputs = {
    # Use a stable NixOS release; update as needed via `nix flake lock --update-input nixpkgs`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      impermanence,
      home-manager,
      ...
    }:
    let
      # Architectures for tooling outputs (devShells, etc.).
      # ISO builds and NixOS VM integration tests remain x86_64-linux only.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Primary system for ISO builds, NixOS configurations, and VM tests.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      nixosConfigurations = {
        nails-os = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit impermanence; };
          modules = [
            ./hosts/nails-os
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
          ];
        };

        nails-os-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit impermanence; };
          modules = [
            ./hosts/nails-os-iso
            home-manager.nixosModules.home-manager
          ];
        };
      };

      sbom = import ./sbom {
        inherit pkgs;
        target = nixosConfigurations.nails-os-iso.config.system.build.toplevel;
        nixpkgsRev = nixpkgs.rev or "unknown";
      };

      vulnixScan = import ./security {
        inherit pkgs;
        target = nixosConfigurations.nails-os-iso.config.system.build.toplevel;
        ignoredCvesFile = ./security/ignored-cves.json;
      };
    in
    {
      inherit nixosConfigurations;

      packages.${system} = {
        nails-os-iso = self.nixosConfigurations.nails-os-iso.config.system.build.isoImage;
        inherit sbom;
        options-doc = import ./options-doc.nix {
          inherit pkgs;
          modules = [
            ./modules/tor.nix
            ./modules/shell-history.nix
            ./modules/home-persistence.nix
            ./modules/impermanence.nix
          ];
        };
      };

      apps.${system} = {
        vulnix-scan = {
          type = "app";
          program = "${vulnixScan}/bin/nails-vulnix-scan";
        };
      };

      # ── Item 7 + 36: Developer shell with linting, formatting, and test tools ─
      devShells = forAllSystems (
        sys:
        let
          p = nixpkgs.legacyPackages.${sys};
        in
        {
          default = p.mkShell {
            packages = with p; [
              nixfmt-rfc-style
              deadnix
              statix
              detect-secrets
              pre-commit
              jq
              qemu
              python3Packages.pytest
            ];
          };
        }
      );

      # ── Item 2 + 36: NixOS VM integration tests ───────────────────────────────
      # VM tests require KVM and are x86_64-linux only.  The vulnix check is
      # also x86_64-only because it references the ISO closure.
      checks = forAllSystems (
        sys:
        nixpkgs.lib.optionalAttrs (sys == "x86_64-linux") {
          vulnix =
            pkgs.runCommand "nails-vulnix-check"
              {
                nativeBuildInputs = [ vulnixScan ];
              }
              ''
                export HOME="$TMPDIR"
                mkdir -p "$HOME"
                nails-vulnix-scan --help > /dev/null
                touch "$out"
              '';

          # 1. Boot test — system reaches multi-user.target with security
          #    hardening modules active.
          boot = pkgs.testers.runNixOSTest {
            name = "nails-boot";
            nodes.machine = {
              imports = [
                ./modules/security.nix
                ./modules/shell-history.nix
              ];
              users.users.amnesia = {
                isNormalUser = true;
                uid = 1000;
                initialPassword = "test";
              };
            };
            testScript = ''
              machine.wait_for_unit("multi-user.target")
              machine.succeed("loginctl list-users")
              # Verify security hardening kernel params are applied
              machine.succeed("grep -q 'slab_nomerge' /proc/cmdline")
              machine.succeed("grep -q 'init_on_alloc=1' /proc/cmdline")
            '';
          };

          # 2. Tor enforcement — transparent proxy rules are installed and the
          #    tor service is running; default output policy is drop.
          tor-enforcement = pkgs.testers.runNixOSTest {
            name = "nails-tor-enforcement";
            nodes.machine = {
              imports = [
                ./modules/tor.nix
                ./modules/network.nix
                ./modules/users.nix
              ];
              nailsOs.tor.useBridges = false;
              services.timesyncd.enable = nixpkgs.lib.mkForce false;
            };
            testScript = ''
              machine.wait_for_unit("tor.service")
              machine.wait_for_unit("nftables.service")
              ruleset = machine.succeed("nft list ruleset")
              # Transparent proxy: TCP is redirected to Tor's TransPort
              assert "dnat to 127.0.0.1:9040" in ruleset, "TransPort DNAT rule missing"
              # Default output policy is drop — no direct internet without Tor
              assert "policy drop" in machine.succeed("nft list chain inet filter output")
              # Tor's own traffic is allowed out
              assert "skuid" in ruleset, "UID-based exemption rules missing"
            '';
          };

          # 3. DNS leak prevention — all DNS is funnelled through Tor's DNSPort;
          #    resolv.conf points to localhost.
          dns-leak-prevention = pkgs.testers.runNixOSTest {
            name = "nails-dns-leak-prevention";
            nodes.machine = {
              imports = [
                ./modules/tor.nix
                ./modules/network.nix
                ./modules/users.nix
              ];
              nailsOs.tor.useBridges = false;
              services.timesyncd.enable = nixpkgs.lib.mkForce false;
            };
            testScript = ''
              machine.wait_for_unit("nftables.service")
              ruleset = machine.succeed("nft list ruleset")
              # Non-tor DNS is redirected to Tor's DNSPort (8853)
              assert "udp dport 53 dnat to 127.0.0.1:8853" in ruleset, \
                  "DNS redirect to Tor DNSPort missing"
              # resolv.conf must point to localhost only
              resolv = machine.succeed("cat /etc/resolv.conf")
              assert "127.0.0.1" in resolv, "resolv.conf missing localhost"
              # No external nameservers that could leak DNS
              machine.fail("grep -E '^nameserver\\s+([^1]|1[^2]|12[^7])' /etc/resolv.conf")
            '';
          };

          # 4. Impermanence — tmpfs-backed paths are volatile and do not survive
          #    reboot, validating the core property that NAILS OS relies on for /.
          impermanence = pkgs.testers.runNixOSTest {
            name = "nails-impermanence";
            nodes.machine = {
              fileSystems."/ephemeral" = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [
                  "mode=755"
                  "size=64M"
                ];
              };
            };
            testScript = ''
              machine.wait_for_unit("multi-user.target")
              # Verify the tmpfs mount is active
              machine.succeed("findmnt -n -o FSTYPE /ephemeral | grep -q tmpfs")
              # Write a file to the volatile mount
              machine.succeed("echo 'volatile-data' > /ephemeral/testfile")
              machine.succeed("test -f /ephemeral/testfile")
              # Reboot — tmpfs contents must not survive
              machine.shutdown()
              machine.start()
              machine.wait_for_unit("multi-user.target")
              machine.fail("test -f /ephemeral/testfile")
            '';
          };

          # 5. Shell history — disabled by default; no .bash_history created
          #    even after running commands.
          shell-history = pkgs.testers.runNixOSTest {
            name = "nails-shell-history";
            nodes.machine = {
              imports = [ ./modules/shell-history.nix ];
              users.users.amnesia = {
                isNormalUser = true;
                uid = 1000;
                initialPassword = "test";
              };
            };
            testScript = ''
              machine.wait_for_unit("multi-user.target")
              # HISTSIZE must be 0
              result = machine.succeed("su - amnesia -c 'echo $HISTSIZE'").strip()
              assert result == "0", f"HISTSIZE is '{result}', expected '0'"
              # Run several commands as amnesia, then verify no history file exists
              machine.succeed("su - amnesia -c 'echo test; ls /; pwd; date'")
              machine.fail("test -f /home/amnesia/.bash_history")
            '';
          };

          # 6. Unsafe Browser — clearnet user is restricted to TCP ports 80/443
          #    and RFC1918 ranges only; all other outbound traffic is dropped.
          unsafe-browser = pkgs.testers.runNixOSTest {
            name = "nails-unsafe-browser";
            nodes.machine = {
              imports = [
                ./modules/tor.nix
                ./modules/network.nix
                ./modules/users.nix
              ];
              nailsOs.tor.useBridges = false;
              services.timesyncd.enable = nixpkgs.lib.mkForce false;
            };
            testScript = ''
              machine.wait_for_unit("nftables.service")
              ruleset = machine.succeed("nft list ruleset")
              # clearnet UID (399) may only use TCP 80, 443
              assert "tcp dport { 80, 443 } accept" in ruleset, \
                  "Clearnet port whitelist rule missing"
              # clearnet UID has a final drop rule — find all rules mentioning
              # the clearnet UID and verify a drop rule exists among them.
              clearnet_rules = [l.strip() for l in ruleset.splitlines()
                                if "skuid 399" in l]
              assert any("drop" in r for r in clearnet_rules), \
                  "Clearnet drop rule missing"
            '';
          };

          # 7. LUKS — dm-crypt kernel module loads and cryptsetup can create,
          #    open, and close a LUKS container, proving the encryption stack works.
          luks = pkgs.testers.runNixOSTest {
            name = "nails-luks";
            nodes.machine = {
              imports = [ ./modules/security.nix ];
              environment.systemPackages = [ pkgs.cryptsetup ];
            };
            testScript = ''
              machine.wait_for_unit("multi-user.target")
              machine.succeed("cryptsetup --version")
              machine.succeed("modprobe dm-crypt")
              # Create a LUKS2 container, open it, verify, and close it
              machine.succeed("dd if=/dev/zero of=/tmp/luks.img bs=1M count=32")
              machine.succeed(
                  "echo -n 'testpassword' | cryptsetup luksFormat "
                  "--batch-mode --pbkdf pbkdf2 --pbkdf-force-iterations 1000 "
                  "/tmp/luks.img -"
              )
              machine.succeed(
                  "echo -n 'testpassword' | cryptsetup luksOpen /tmp/luks.img testcrypt -"
              )
              machine.succeed("cryptsetup status testcrypt")
              machine.succeed("cryptsetup luksClose testcrypt")
            '';
          };
        }
      );
    };
}
