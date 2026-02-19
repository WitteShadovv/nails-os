{
  description = "NAILS OS (TAILS-like) NixOS with impermanence";

  inputs = {
    # Use a stable NixOS release; update as needed via `nix flake lock --update-input nixpkgs`.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    impermanence.url = "github:nix-community/impermanence";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, impermanence, home-manager, ... }:
    let system = "x86_64-linux";
    in {
      nixosConfigurations.nails-os = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit impermanence; };
        modules = [
          ./hosts/nails-os
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
        ];
      };

      nixosConfigurations.nails-os-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit impermanence; };
        modules =
          [ ./hosts/nails-os-iso home-manager.nixosModules.home-manager ];
      };

      packages.${system}.nails-os-iso =
        self.nixosConfigurations.nails-os-iso.config.system.build.isoImage;
    };
}
