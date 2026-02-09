{
  can,
  top,
  config,
  lib,
  name,
  node,
  ...
}: let
  inherit (config.canivete) activator args builder configuration type;
  inherit (node.config.canivete) os system;
  inherit (top.config.canivete.deploy.canivete) flakes modules;
  inherit (flakes.deploy.lib.${system}) activate;
in {
  imports = [./generic.nix];
  options = {
    path = can.pathInStore "path to activation script for given derivation" {default = activator configuration;};
    profilePath = can.opt.path "profile installation path" {};
    canivete = {
      configuration = can.module "central module and configuration derviation for profile" {apply = builder;};
      type = can.enum ["home-manager" "nixos" "darwin" "droid" "custom"] "config module class" {
        default =
          {
            nixos = "nixos";
            macos = "darwin";
            windows = "nixos";
            linux = "home-manager";
            android = "droid";
          }
          .${
            os
          };
      };
      activator = can.function.pathInStore "how to build activation script from derivation" {
        default =
          {
            inherit (activate) nixos darwin home-manager;
            droid = base: (activate.custom // {dryActivate = "$PROFILE/activate switch --dry-run";}) base.activationPackage "$PROFILE/activate switch";
            custom = base: activate.custom base.canivete.activationPackage (lib.getExe base.canivete.activationPackage);
          }
          .${
            type
          };
      };
      args = can.attrs.anything "arguments based to configuration" {};
      builder = can.function.raw "convert modules to configurations" {
        default =
          {
            nixos = modules:
              flakes.nixos.lib.nixosSystem {
                specialArgs = args;
                modules = [modules];
              };
            darwin = modules:
              flakes.darwin.lib.darwinSystem {
                specialArgs = args;
                modules = [modules];
              };
            droid = modules:
              top.withSystem system ({pkgs, ...}:
                flakes.droid.lib.nixOnDroidConfiguration {
                  inherit pkgs;
                  extraSpecialArgs = args;
                  modules = [modules];
                });
            home-manager = modules:
              top.withSystem system ({pkgs, ...}:
                flakes.home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;
                  extraSpecialArgs = args;
                  modules = [modules];
                });
            custom = modules:
              lib.evalModules {
                specialArgs = args;
                modules = [modules];
              };
          }
          .${
            type
          };
      };
    };
  };
  config = {
    user = let
      users = {
        home-manager = name;
        nixos = "root";
        darwin = "root";
      };
    in
      lib.mkDefault (users.${type} or null);
    canivete.args = {
      inherit can top node;
      # Avoid fixpoint infinite recursion
      profile = {
        inherit name;
        config = {inherit (config) canivete;};
      };
    };
    canivete.configuration =
      modules.${
        type
      }
      or {
        options.canivete.activationPackage = can.package "final package for custom profile" {};
      };
  };
}
