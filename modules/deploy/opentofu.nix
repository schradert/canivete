{
  canivete,
  config,
  lib,
  ...
}: let
  inherit (config.canivete.deploy) nodes;
in {
  canivete.deploy = {config, ...}: let
    inherit (config.canivete) flakes;
  in {
    options.nodes = canivete.mkNestedSubmodule {
      options.profiles = canivete.mkNestedSubmodule ({
        config,
        name,
        node,
        ...
      }: let
        inherit (config.canivete) type;
        resource_name = "${type}_${node.name}_${name}";
        nixFlags =
          if type == "droid"
          then "--impure"
          else "";
      in {
        canivete.configuration = {
          options.canivete.opentofu = canivete.mkModuleOption {};
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
  perSystem = {config, ...}: {
    config = lib.mkIf config.canivete.opentofu.enable {
      canivete.opentofu.workspaces.deploy = {
        plugins = ["hashicorp/null" "hashicorp/external"];
        modules.imports = let
          getProfileImport = lib.getAttrFromPath ["canivete" "configuration" "config" "canivete" "opentofu"];
          getNodeImports = node: map getProfileImport (builtins.attrValues node.profiles);
        in
          lib.pipe nodes [builtins.attrValues (builtins.concatMap getNodeImports)];
      };
    };
  };
}
