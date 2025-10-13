flake @ {
  canivete,
  config,
  lib,
  withSystem,
  ...
}: let
  inherit (canivete) mkNullableOption;
  inherit (config.canivete.deploy.canivete) flakes modules;
  inherit (lib) evalModules getExe mkDefault mkIf mkMerge mkOption optionalAttrs types;
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
    imports = [./generic.nix];
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
      opentofu = mkOption {
        type = deferredModule;
        default = {};
        description = "Extra module to be injected in OpenTofu workspace for the node";
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
      canivete.opentofu = {
        config,
        pkgs,
        ...
      }: let
        inherit (config.resource) null_resource;
        resource_name = "${type}_${node.name}_${name}";
        nixFlags =
          if type == "droid"
          then "--impure"
          else "";
      in {
        config = mkMerge [
          {
            data.external.${resource_name}.program = pkgs.execBash "nix eval .#canivete.deploy.nodes.${node.name}.profiles.${name}.path.drvPath | ${getExe pkgs.jq} '{drvPath:.}'";
            resource.null_resource.${resource_name} = {
              triggers.drvPath = "\${ data.external.${resource_name}.result.drvPath }";
              # deploy-rs currently runs all flake checks, which can fail when correctly deploying
              # TODO submit issue report to only run checks that deploy-rs creates
              provisioner.local-exec.command = "${getExe flakes.deploy.packages.${pkgs.system}.default} --skip-checks .#\"${node.name}\".\"${name}\" ${nixFlags}";
            };
          }
          # TODO support installation of nix system manager on every platform
          (mkIf (type == "nixos") {
            module."${resource_name}_install" = mkMerge [
              {
                source = "${flakes.anywhere}//terraform/install";
                target_host = node.config.hostname;
                flake = ".#${node.name}";
              }
              (mkIf (flakes.disko == null) {phases = ["kexec" "install" "reboot"];})
              (mkIf (null_resource ? sops) {depends_on = ["null_resource.sops"];})
            ];
            data.external.${resource_name}.depends_on = ["module.${resource_name}_install"];
          })
        ];
      };
    };
  }
