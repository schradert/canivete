{
  inputs,
  lib,
  ...
}: let
  inherit (config.canivete) nixidy;
in {
  config = lib.mkMerge [
    {perSystem.canivete.opentofu.workspaces.deploy = ./opentofu.nix;}
    (lib.mkIf nixidy.enable {
      perSystem = perSystem @ {
        inputs',
        pkgs,
        self',
        system,
        ...
      }: {
        packages.nixidy = inputs'.nixidy.packages.default;
        devenv.shells.default = {
          git-hooks.hooks.lychee.toml.exclude = ["svc.cluster.local"];
          packages = [self'.packages.nixidy];
        };
        legacyPackages.nixidyEnvs.${system} = inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          inherit (nixidy) envs libOverlay;
          modules = [nixidy.shared];
          extraSpecialArgs = nixidy.args // {inherit perSystem;};
          charts = (inputs.nixhelm.chartsDerivations.${system} or {}) // nixidy.charts;
        };
      };
    })
  ];
}
