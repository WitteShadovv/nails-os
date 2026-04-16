# Generates HTML documentation for all nailsOs.* NixOS options.
#
# Usage from flake.nix — add to packages.${system}:
#
#   options-doc = import ./options-doc.nix {
#     inherit pkgs;
#     modules = [
#       ./modules/tor.nix
#       ./modules/shell-history.nix
#       ./modules/impermanence.nix
#       ./modules/home-persistence.nix
#       ./modules/security.nix
#       # ... any other modules defining nailsOs.* options
#     ];
#   };
#
{ pkgs, modules }:

let
  # Evaluate the module system with only our modules (+ base NixOS for
  # config.users etc.) to extract option declarations.
  eval = pkgs.lib.evalModules {
    modules = modules ++ [
      # Provide a minimal base so modules that reference config.users,
      # config.services, etc. don't fail during option discovery.
      ({ lib, ... }: {
        options = {
          users = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          services = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          environment = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          programs = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          networking = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          security = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          boot = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          system = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        };
        config._module.check = false;
      })
    ];
  };

  # Filter to only nailsOs.* options.
  nailsOpts = pkgs.lib.filterAttrs (name: _: pkgs.lib.hasPrefix "nailsOs" name)
    eval.options;

  optionsDoc = pkgs.nixosOptionsDoc { options = nailsOpts; };
in optionsDoc.optionsCommonMark
