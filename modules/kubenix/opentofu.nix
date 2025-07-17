{
  perSystem = {
    canivete,
    config,
    lib,
    ...
  }: let
    inherit (config.canivete.kubenix) enable clusters;
    inherit (lib) attrNames filterAttrs getExe mapAttrsToList mapAttrs' mkIf mkMerge nameValuePair pipe types;
    clusterRef = with types; coercedTo (enum (attrNames clusters)) (name: clusters.${name}) raw;
  in {
    options.canivete.opentofu.workspaces = canivete.mkNestedSubmodule ({config, ...}: {
      options.kubernetes.cluster = canivete.mkNullableOption clusterRef {description = "Cluster in this workspace";};
      config.plugins = mkIf (config.kubernetes.cluster != null) ["hashicorp/null"];
    });
    config = mkMerge [
      {canivete.kubenix.sharedModules.options.canivete.root = canivete.mkNullableOption types.str {};}
      (mkIf enable {
        canivete.opentofu.sharedModules = {
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
      })
    ];
  };
}
