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

  outputs = { self, nixpkgs, impermanence, home-manager, ... }:
    let
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
          modules =
            [ ./hosts/nails-os-iso home-manager.nixosModules.home-manager ];
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
    in {
      inherit nixosConfigurations;

      packages.${system} = {
        nails-os-iso =
          self.nixosConfigurations.nails-os-iso.config.system.build.isoImage;
        inherit sbom;
      };

      apps.${system} = {
        vulnix-scan = {
          type = "app";
          program = "${vulnixScan}/bin/nails-vulnix-scan";
        };
      };

      checks.${system} = {
        vulnix = pkgs.runCommand "nails-vulnix-check" {
          nativeBuildInputs = [ vulnixScan ];
        } ''
          export HOME="$TMPDIR"
          mkdir -p "$HOME"
          nails-vulnix-scan --help > /dev/null
          touch "$out"
        '';
      };
    };
}
