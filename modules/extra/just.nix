{
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (canivete) mkEnabledOption;
    inherit (lib) getExe mkOption types setAttrByPath attrNames pipe filterAttrs getAttr toList attrValues concatStringsSep mkIf mkMerge;
    inherit (types) attrsOf coercedTo str submodule enum package;
    inherit (pkgs) writeText just wrapProgram mkShell git convco;
    cfg = config.canivete.just;
  in {
    options.canivete.just = {
      enable = mkEnabledOption "Just command runner";
      recipes = mkOption {
        type = attrsOf (coercedTo str (setAttrByPath ["command"]) (submodule ({
          config,
          name,
          ...
        }: {
          options.enable = mkEnabledOption name;
          options.command = mkOption {
            type = str;
            description = "Actual command to run as part of this unique recipe";
          };
          options.recipe = mkOption {
            type = str;
            description = "Literal recipe in justfile";
            default = ''
              ${name}:
                  ${config.command}
            '';
          };
        })));
        description = "Commands to include in just";
        default = {};
      };
      defaultRecipe = mkOption {
        type = enum (attrNames cfg.recipes);
        description = "Recipe to run by default with just";
        default = "list";
      };
      justfile = mkOption {
        type = package;
        description = "Justfile with recipe commands";
        default = pipe cfg.recipes [
          (filterAttrs (_: getAttr "enable"))
          (recipes: toList (recipes.${cfg.defaultRecipe} or []) ++ attrValues (removeAttrs recipes [cfg.defaultRecipe]))
          (map (getAttr "recipe"))
          (concatStringsSep "\n")
          (writeText "justfile")
        ];
      };
      basePackage = mkOption {
        type = package;
        description = "Base just package to use";
        default = just;
      };
      finalPackage = mkOption {
        type = package;
        readOnly = true;
        description = "Final just executable";
        default = wrapProgram cfg.basePackage "just" "just" "--add-flags \"--justfile ${cfg.justfile}\"" {};
      };
      devShell = mkOption {
        type = package;
        description = "Development shell with just executable";
        default = mkShell {
          packages = [cfg.finalPackage];
          shellHook = "export JUST_WORKING_DIRECTORY=\"$(${getExe git} rev-parse --show-toplevel)\"";
        };
      };
    };
    config = mkMerge [
      {canivete.just.recipes.list = "@just --list";}
      (mkIf cfg.enable {
        canivete.just.recipes."changelog *ARGS" = "${getExe convco} changelog --prefix \"\" {{ ARGS }}";
      })
      (mkIf config.canivete.devShells.enable {canivete.devShells.shells.shared.inputsFrom = [cfg.devShell];})
    ];
  };
}
