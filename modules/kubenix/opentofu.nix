{
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (config.canivete.kubenix) clusters;
    inherit (lib) attrNames filterAttrs getExe mapAttrsToList mapAttrs' mkIf mkOption nameValuePair pipe types;
    inherit (types) attrsOf coercedTo enum nullOr raw str submodule;
  in {
    options.canivete.opentofu = {
      workspaces = mkOption {
        type = attrsOf (submodule ({config, ...}: {
          options.kubernetes.cluster = mkOption {
            type = nullOr (coercedTo (enum (attrNames clusters)) (name: clusters.${name}) raw);
            description = "Kubernetes cluster to deploy in this OpenTofu workspace";
          };
          config.plugins = mkIf (config.kubernetes.cluster != null) ["hashicorp/null"];
        }));
      };
    };
    config.canivete.kubenix.sharedModules = {
      options.canivete.root = mkOption {
        type = str;
        description = "Name of node to treat as deployment root";
      };
    };
    config.canivete.opentofu.sharedModules = {
      flake,
      pkgs,
      workspace,
      ...
    }: let
      inherit (workspace.config.kubernetes) cluster;
      inherit (cluster.config) canivete kubernetes;
      nixosClusterNodes =
        filterAttrs
        (_: node: node.canivete.os == "nixos" && node.profiles.system.canivete.configuration.config.canivete.kubernetes.enable)
        flake.config.canivete.deploy.nodes;
    in {
      config = mkIf (cluster != null) {
        resource.null_resource.kubernetes = {
          depends_on = pipe nixosClusterNodes [
            (mapAttrsToList (name: _: "null_resource.nixos_${name}_system"))
            (mkIf (workspace.name == "deploy"))
          ];
          triggers.drv = kubernetes.resultYAML.drvPath;
          provisioner.local-exec.command = "${getExe canivete.script} ${getExe pkgs.kapp} deploy --yes --diff-changes --app everything --file -";
        };
        module = pipe nixosClusterNodes [
          (filterAttrs (name: _: name != canivete.root))
          (mapAttrs' (name: _: nameValuePair "nixos_${name}_system_install" {depends_on = ["module.nixos_${canivete.root}_system_install"];}))
        ];
      };
    };
  };
}
