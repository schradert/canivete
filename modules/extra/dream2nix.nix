{inputs, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkEnableOption mkOption types concat toList mkDefault mapAttrs getAttr mkIf;
    inherit (types) listOf deferredModule package attrsOf submodule nullOr;
    cfg = config.canivete.dream2nix;
  in {
    options.canivete.dream2nix = {
      enable = mkEnableOption "Dream2nix packaging" // {default = inputs ? dream2nix;};
      sharedModules = mkOption {
        type = listOf deferredModule;
        default = [];
        description = "Dream2Nix modules used in all packages";
      };
      sharedShells = mkOption {
        type = listOf package;
        default = [];
        description = "Shells shared by package devShells";
      };
      packages = mkOption {
        default = {};
        description = "Dream2Nix packages";
        type = attrsOf (submodule ({config, ...}: {
          options = {
            module = mkOption {
              type = deferredModule;
              description = "Primary module to pass specific package config";
            };
            modules = mkOption {
              type = listOf deferredModule;
              description = "All modules used to build package";
              default = concat cfg.sharedModules [config.module];
            };
            package = mkOption {
              type = package;
              description = "Final package built with Dream2Nix";
              default = inputs.dream2nix.lib.evalModules {
                inherit (config) modules;
                packageSets.nixpkgs = pkgs;
              };
            };
            devShell = mkOption {
              type = nullOr package;
              description = "Development shell for this package";
              default = pkgs.mkShell {inputsFrom = concat cfg.sharedShells [config.package.devShell];};
            };
          };
        }));
      };
    };
    config = mkIf cfg.enable {
      packages = mapAttrs (_: getAttr "package") cfg.packages;
      canivete.dream2nix.sharedModules = toList ({config, ...}: {
        paths.projectRoot = toString inputs.self;
        paths.projectRootFile = "flake.nix";
        paths.package = mkDefault config.mkDerivation.src;
      });
    };
  };
}
