flake @ {
  canivete,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.canivete) nixidy;
  inherit (lib) types;
in {
  options.canivete.nixidy = lib.mkOption {
    default = {};
    type = types.submodule (nixidy: {
      options = {
        enable = lib.mkEnableOption "Nixidy" // {default = inputs ? nixidy;};
        shared = canivete.mkModuleOption {};
        args = canivete.mkAttrsOption types.anything {};
        envs = canivete.mkModulesOption {};
        charts = canivete.mkAttrsOption types.anything {};
        # TODO convert to multiple overlays
        libOverlay = canivete.mkNullableOption (with types; functionTo (functionTo (attrsOf anything))) {};
        k8s = lib.mkOption {
          default = "k3s";
          description = "Kubernetes distribution";
          type = types.enum ["k3s" "rke2"];
        };
      };
      config = {
        args = {inherit canivete flake nixidy;};
        shared = ./nixidy;
        envs.prod = {};
      };
    });
  };
  config = lib.mkMerge [
    {canivete.deploy.canivete.modules.nixos = ./nixos.nix;}
    {perSystem.canivete.opentofu.workspaces.deploy = ./opentofu.nix;}
    (lib.mkIf nixidy.enable {
      perSystem = perSystem @ {
        pkgs,
        system,
        ...
      }: {
        canivete.pre-commit.settings.hooks.lychee.toml.exclude = ["svc.cluster.local"];
        legacyPackages.nixidyEnvs.${system} = inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          inherit (nixidy) envs libOverlay;
          modules = [nixidy.shared];
          extraSpecialArgs = nixidy.args // {inherit perSystem;};
        };
      };
    })
  ];
}
