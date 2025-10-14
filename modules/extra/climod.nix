{inputs, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.canivete) climod;
    inherit (lib) mapAttrs' mkDefault mkEnableOption mkIf mkOption nameValuePair types;
    inherit (types) attrsOf deferredModule submodule package functionTo;
    climodToJust = name: program: nameValuePair "${name} {{ ARGS }}" program.package;
  in {
    config = mkIf climod.enable {
      canivete.just.recipes = mapAttrs' climodToJust climod.programs;
    };
    options.canivete.climod = {
      enable = mkEnableOption "Climod script builder" // {default = inputs ? climod;};
      programs = mkOption {
        default = {};
        description = "Executables";
        type = attrsOf (submodule ({
          name,
          config,
          ...
        }: {
          options.builder = mkOption {
            default = pkgs.callPackage (inputs.climod + "/default.nix") {inherit pkgs;};
            description = "Function to create executable with configuration";
            type = functionTo package;
          };
          options.module = mkOption {
            default = deferredModule;
            description = "Configuration";
          };
          options.package = mkOption {
            default = config.builder config.module;
            description = "Executable";
            type = package;
          };
          config.module.name = mkDefault name;
        }));
      };
    };
  };
}
