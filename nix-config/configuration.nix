{ ... }:
{
  # Compatibility entry point for tooling that expects /etc/nixos/configuration.nix.
  # The flake remains the canonical source of truth.
  imports = [ ./hosts/nails-os ];
}
