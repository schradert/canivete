{
  inputs,
  lib,
  ...
}: let
  inherit (lib) mapAttrs' mkAliasOptionModule mkIf mkOption nameValuePair optional types;
in {
  imports = optional (inputs ? process-compose) inputs.process-compose.flakeModule;
  perSystem = {config, ...}: {
    imports = optional (inputs ? process-compose) (mkAliasOptionModule ["canivete" "process-compose"] ["process-compose"]);
    options.canivete.process-compose = mkOption {
      default = {};
      type = types.attrsOf (types.submoduleWith {
        modules = optional (inputs ? services) inputs.services.processComposeModules.default;
      });
    };
    config = mkIf config.canivete.just.enable {
      canivete.just.recipes =
        mapAttrs'
        (name: _: nameValuePair "${name} *ARGS" "nix run .#${name} \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}")
        config.canivete.process-compose;
    };
  };
}
