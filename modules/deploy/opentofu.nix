{
  can,
  config,
  lib,
  ...
}: {
  perSystem.canivete.opentofu.workspaces.deploy = {
    plugins = ["hashicorp/null" "hashicorp/external"];
    modules.imports = let
      getProfileImport = lib.getAttrFromPath ["canivete" "configuration" "config" "canivete" "opentofu"];
      getNodeImports = node: map getProfileImport (builtins.attrValues node.profiles);
    in
      lib.pipe config.canivete.deploy.nodes [builtins.attrValues (builtins.concatMap getNodeImports)];
  };
  canivete.deploy = _: {
    options.nodes = can.attrs.withSubmodule {
      options.profiles = can.attrs.withSubmodule ({
        config,
        flake,
        name,
        node,
        ...
      }: let
        inherit (flake.config.canivete) flakes;
        inherit (config.canivete) type;
        resource_name = "${type}_${node.name}_${name}";
        nixFlags = can.ifElse (type == "droid") "--impure" "";
      in {
        canivete.configuration = {
          options.canivete.opentofu = can.module "OpenTofu modules for profile" {};
          config.canivete.opentofu = {
            config,
            pkgs,
            ...
          }: {
            config = lib.mkMerge [
              {
                data.external.${resource_name}.program = pkgs.execBash "nix eval .#canivete.deploy.nodes.${node.name}.profiles.${name}.path.drvPath | ${lib.getExe pkgs.jq} '{drvPath:.}'";
                resource.null_resource.${resource_name} = {
                  triggers.drvPath = "\${ data.external.${resource_name}.result.drvPath }";
                  # deploy-rs currently runs all flake checks, which can fail when correctly deploying
                  # TODO submit issue report to only run checks that deploy-rs creates
                  provisioner.local-exec.command = "${lib.getExe flakes.deploy.packages.${pkgs.system}.default} --skip-checks .#\"${node.name}\".\"${name}\" ${nixFlags}";
                };
              }
              # TODO support installation of nix system manager on every platform
              (lib.mkIf (type == "nixos") {
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
              })
            ];
          };
        };
      });
    };
  };
}
