{
  can,
  config,
  lib,
  ...
}: let
  inherit (config.canivete.deploy) canivete nodes;
  inherit (canivete) flakes;
  getResourceName = node: profile: "${profile.config.canivete.type}_${node.name}_${profile.name}";
in {
  config = lib.mkIf canivete.enable {
    perSystem.canivete.opentofu.workspaces.deploy = {
      plugins = ["hashicorp/null" "hashicorp/external"];
      modules.imports = let
        getProfileImport = lib.getAttrFromPath ["canivete" "configuration" "config" "canivete" "opentofu"];
        getNodeImports = node: map getProfileImport (builtins.attrValues node.profiles);
      in
        lib.pipe nodes [builtins.attrValues (builtins.concatMap getNodeImports)];
    };
    canivete.deploy.canivete.modules = {
      shared = {node, profile, pkgs, ...}: let
        resource_name = getResourceName node profile;
        nixFlags = can.ifElse (profile.config.canivete.type == "droid") "--impure" "";
      in {
        options.canivete.opentofu = can.module "OpenTofu modules for profile" {};
        config.canivete.opentofu = {
          data.external.${resource_name}.program = pkgs.execBash "nix eval .#canivete.deploy.nodes.${node.name}.profiles.${profile.name}.path.drvPath | ${lib.getExe pkgs.jq} '{drvPath:.}'";
          resource.null_resource.${resource_name} = {
            triggers.drvPath = "\${ data.external.${resource_name}.result.drvPath }";
            # deploy-rs currently runs all flake checks, which can fail when correctly deploying
            # TODO submit issue report to only run checks that deploy-rs creates
            provisioner.local-exec.command = "${lib.getExe flakes.deploy.packages.${pkgs.system}.default} --skip-checks .#\"${node.name}\".\"${profile.name}\" ${nixFlags}";
          };
        };
      };
      # TODO support installation of nix system manager on every platform
      nixos = {config, node, profile, ...}: let
        resource_name = getResourceName node profile;
      in {
        canivete.opentofu = {
          data.external.${resource_name}.depends_on = ["module.${resource_name}_install"];
          module."${resource_name}_install" = lib.mkMerge [
            {
              source = "${flakes.anywhere}//terraform/install";
              target_host = node.config.hostname;
              flake = ".#${node.name}";
            }
            (lib.mkIf (flakes.disko == null) {phases = ["kexec" "install" "reboot"];})
            (lib.mkIf (config.resource.null_resource ? sops) {depends_on = ["null_resource.sops"];})
          ];
        };
      };
    };
  };
}
