flake @ {
  canivete,
  config,
  lib,
  withSystem,
  ...
}: let
  inherit (canivete) mkNullableOption;
  inherit (config.canivete.deploy.canivete) flakes modules;
  inherit (lib) evalModules getExe mkDefault mkOption optionalAttrs types;
  inherit (types) deferredModule enum functionTo package path pathInStore raw;
in
  profile @ {
    config,
    name,
    node,
    ...
  }: let
    inherit (config.canivete) activator builder configuration type;
    inherit (flakes.deploy.lib.${node.config.canivete.system}) activate;
    inherit (node.config.canivete) os system;
  in {
    imports = [(import ./generic.nix flake)];
    options.path = mkOption {
      type = pathInStore;
      default = activator configuration;
      description = "Path to activation script for given derivation";
    };
    options.profilePath = mkNullableOption path {description = "Profile installation path";};
    options.canivete = {
      type = mkOption {
        type = enum ["home-manager" "nixos" "darwin" "droid" "custom"];
        default =
          {
            nixos = "nixos";
            macos = "darwin";
            windows = "nixos";
            linux = "home-manager";
            android = "droid";
          }
          .${os};
        description = "Configuration module class (type of derivation)";
      };
      activator = mkOption {
        type = functionTo pathInStore;
        default =
          {
            inherit (activate) nixos darwin home-manager;
            droid = base: (activate.custom // {dryActivate = "$PROFILE/activate switch --dry-run";}) base.activationPackage "$PROFILE/activate switch";
            custom = base: activate.custom base.canivete.activationPackage (getExe base.canivete.activationPackage);
          }
          .${type};
        description = "How to build activation script for a derivation";
      };
      builder = mkOption {
        type = functionTo raw;
        default =
          {
            nixos = modules: flakes.nixos.lib.nixosSystem {modules = [modules];};
            darwin = modules: flakes.darwin.lib.darwinSystem {modules = [modules];};
            droid = modules:
              withSystem system ({pkgs, ...}:
                flakes.droid.lib.nixOnDroidConfiguration {
                  inherit pkgs;
                  modules = [modules];
                });
            home-manager = modules:
              withSystem system ({pkgs, ...}:
                flakes.home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;
                  modules = [modules];
                });
            custom = modules: evalModules {modules = [modules];};
          }
          .${type};
        description = "Convert modules to configurations";
      };
      configuration = mkOption {
        type = deferredModule;
        default = {};
        description = "Central module and configuration derivation for profile";
        apply = builder;
      };
    };
    config = {
      user = mkDefault ({
          home-manager = name;
          nixos = "root";
        }
        .${type}
        or null);
      canivete.configuration.imports = [
        (withSystem system (perSystem: {_module.args = {inherit canivete flake node perSystem profile;};}))
        (modules.${type}
          or {
            options.canivete.activationPackage = mkOption {
              type = package;
              description = "Final package for custom profile";
            };
          })
        (optionalAttrs (type == "home-manager") {home.username = name;})
        # TODO when should I replace this with nixos-facter, etc.?
        (optionalAttrs (type != "custom") {nixpkgs.hostPlatform = system;})
      ];
    };
  }
