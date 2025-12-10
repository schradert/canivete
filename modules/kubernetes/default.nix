flake @ {
  can,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.canivete) nixidy;
in {
  options.canivete.nixidy = can.submodule "nixidy" (nixidy: {
    options = {
      enable = can.enable "nixidy" {default = inputs ? nixidy;};
      shared = can.module "shared modules" {};
      args = can.attrs.anything "nixidy args" {};
      envs = can.attrs.module "environment configs" {};
      charts = can.attrs.anything "nixidy charts" {};
      libOverlay = can.overlay "extra lib functions" {};
      k8s = can.enum ["k3s" "rke2"] "kubernetes distribution" {};
    };
    config = {
      args = {inherit can flake nixidy;};
      shared = ./nixidy;
      envs.prod = {};
    };
  });
  config = lib.mkMerge [
    {canivete.deploy.canivete.modules.nixos = ./nixos.nix;}
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
