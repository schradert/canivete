{
  flake,
  lib,
  perSystem,
  ...
}: let
  inherit (flake.config.canivete.meta) root;
  nixosClusterNodes =
    lib.filterAttrs
    (_: node: node.canivete.os == "nixos" && node.profiles.system.canivete.configuration.config.canivete.kubernetes.enable)
    flake.config.canivete.deploy.nodes;
  hasKubernetesNode = nixosClusterNodes != {};
in {
  config = lib.mkIf (hasKubernetesNode && flake.config.canivete.opentofu.enable) {
    passwords.k8s-token.length = 21;
    plugins = ["hashicorp/null"];
    modules = {
      resource.null_resource.kubernetes-bootstrap = {
        depends_on = ["null_resource.nixos_${root}_system_install"];
        provisioner.local-exec.command = lib.getExe perSystem.self'.legacyPackages.nixidyEnvs.${perSystem.system}.prod.config.build.scripts.bootstrap;
      };
      module = lib.pipe nixosClusterNodes [
        (lib.filterAttrs (name: _: name != root))
        (lib.mapAttrs' (name: _: lib.nameValuePair "nixos_${name}_system_install" {depends_on = ["null_resource.kubernetes-bootstrap"];}))
      ];
    };
  };
}
