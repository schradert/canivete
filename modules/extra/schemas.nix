{
  canivete,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (builtins) functionArgs isAttrs isFunction isString mapAttrs;
  inherit (canivete) mkFlakeOption mkNullableOption;
  inherit (config) systems;
  inherit (config.canivete) schemas;
  inherit (lib) filterAttrsRecursive getExe mkEnableOption mkIf mkMerge mkOption types;
  inherit (types) anything attrsOf bool either enum functionTo listOf package str submodule;
in {
  options.canivete.schemas = {
    enable = mkEnableOption "flake-schemas support" // {default = schemas.flakes.schemas != null && schemas.flakes.nix != null;};
    flakes.schemas = mkFlakeOption "flake-schemas" {};
    flakes.nix = mkFlakeOption "nix-flake-schemas" {};
    lib = mkOption {
      type = let
        recursive = attrsOf (either (functionTo anything) recursive);
      in
        recursive;
      default = {};
      description = "Helper functions";
    };
    schemas = mkOption {
      default = {};
      type = attrsOf (submodule ({config, ...}: {
        options = let
          children = attrsOf (submodule {
            options = {
              forSystems = mkNullableOption (listOf (enum systems)) {description = "system parents";};
              shortDescription = mkNullableOption str {description = "short description";};
              derivation = mkNullableOption package {description = "actual derivation";};
              evalChecks = mkNullableOption (attrsOf bool) {description = "evaluation checks";};
              what = mkNullableOption str {description = "basic type description";};
              isFlakeCheck = mkNullableOption bool {description = "whether to test with flake check";};
              children = mkNullableOption children {description = "further tree keys";};
            };
          });
        in {
          version = mkOption {
            type = enum [1];
            default = 1;
            description = "flake-schemas version";
          };
          doc = mkOption {
            type = str;
            default = "";
            description = "schema description";
          };
          allowIFD = mkNullableOption bool {description = "allow import-from-derivation";};
          canivete.children = mkOption {
            type = children;
            default = {};
            description = "actual tree keys";
          };
          inventory = mkOption {
            description = "how to derive schema hierarchy";
            default = _: config.canivete.children;
            type = functionTo (submodule {
              options.children = mkOption {
                type = children;
                description = "tree keys";
              };
            });
          };
        };
      }));
    };
  };
  config = mkIf schemas.enable {
    # TODO do I need to further sanitize this output to avoid schema conflicts with flake-schemas?
    flake.schemas = filterAttrsRecursive (name: value: name != "canivete" && value != null) schemas.schemas;
    canivete.schemas.lib = mkMerge [
      inputs.flake-schemas.lib
      {
        checkDerivation = drv:
          drv.type
          or null
          == "derivation"
          && drv ? drvPath
          && drv ? name
          && isString drv.name;
        checkModule = func: module:
          isAttrs module
          || (isFunction module && func module);
        eachChild = func: output: schemas.lib.mkChildren (mapAttrs func output);
      }
    ];
    # TODO is it possible to autogenerate every schema recursively up until functions?
    canivete.schemas.schemas = mkMerge [
      inputs.flake-schemas.schemas
      {
        # TODO why is this giving me null children?!
        flakeModules.inventory = schemas.lib.eachChild (_: module: {
          what = "flake-parts module";
          evalChecks.isModule = schemas.lib.checkModule (mod: (functionArgs mod) ? flake-parts-lib) module;
        });
      }
    ];
    perSystem = {system, ...}: {
      # TODO why does this not use the right version of nix from flake-schemas?
      canivete.just.recipes.inspect = "${getExe schemas.flakes.nix.packages.${system}.default} -- flake show";
    };
  };
}
