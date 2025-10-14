{
  config,
  inputs,
  ...
}: let
  inherit (config) perInput;
in {
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (lib) replaceStrings attrValues mkDefault mkOption types mkEnableOption mkIf;
    inherit (types) lazyAttrsOf submodule raw package;

    # Containers rely on the Linux kernel, so for this to work on a Darwin client, configure distributed builds
    system'' = replaceStrings ["darwin"] ["linux"] system;

    cfg = config.canivete.arion;
    inherit (inputs.self.canivete.${system''}.pkgs) pkgs;
    modules = attrValues cfg.modules;
  in {
    options.canivete.arion = {
      enable = mkEnableOption "arion docker compose projects" // {default = inputs ? arion;};
      flake = mkOption {
        type = raw;
        description = "Arion flake input";
        default = inputs.arion;
      };
      projects = mkOption {
        type = lazyAttrsOf (submodule ({
          name,
          config,
          ...
        }: {
          options = {
            modules = canivete.mkModulesOption {};
            composition = mkOption {
              type = raw;
              description = "Evaluated arion configuration";
              default = cfg.flake.lib.eval {inherit modules pkgs;};
            };
            yaml = mkOption {
              type = package;
              description = "docker-compose YAML output";
              default = config.composition.config.out.dockerComposeYaml;
            };
            basePackage = mkOption {
              type = package;
              description = "Base arion package to use";
              default = cfg.flake.packages.${system}.arion;
            };
            finalPackage = mkOption {
              type = package;
              description = "Final arion executable";
              default = pkgs.wrapProgram config.basePackage "arion" "arion" "--add-flags \"--prebuilt-file ${config.yaml}\"" {};
            };
          };
          config.modules.builtin = {
            # Mismatched systems should buildLayeredImage to allow running on host
            options.services = mkOption {
              type = lazyAttrsOf (submodule {config.image.asStream = system == system'';});
              default = {};
            };
            # Also share self' of the Linux system variant
            config._module.args.self'' = perInput system'' inputs.self;
            config.project.name = mkDefault name;
          };
        }));
      };
    };
    config = mkIf cfg.enable {
      # TODO why does this cause a nix daemon disconnection? move-docs.sh missing? cross platform is HARD
      # config.canivete.just.recipes."arion *ARGS" = "${getExe cfg.finalPackage} {{ ARGS }}";
    };
  };
}
