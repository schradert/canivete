{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  inherit (config.canivete) nixidy;
in {
  config = lib.mkIf nixidy.enable {
    packages = [inputs.nixidy.packages.${system}.default];
    git-hooks.hooks.lychee.toml.exclude = ["svc.cluster.local"];
    outputs.nixidy = inputs.nixidy.lib.mkEnvs {
      inherit pkgs;
      inherit (nixidy) envs libOverlay;
      modules = [nixidy.shared];
      extraSpecialArgs = nixidy.args;
      charts = (inputs.nixhelm.chartsDerivations.${system} or {}) // nixidy.charts;
    };
  };
}
