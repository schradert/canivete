flake @ {inputs, ...}: {
  imports = [./nixos.nix ./opentofu.nix];
  perSystem = perSystem @ {
    canivete,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (lib) getExe mapAttrs mkDefault mkEnableOption mkIf mkOption types mkMerge pipe mapAttrsToList;
    inherit (types) attrsOf deferredModule package str submodule;
  in {
    imports = [./k3d.nix];
    config = mkIf config.canivete.kubenix.enable {
      canivete.pre-commit.settings.hooks.lychee.toml.exclude = ["svc.cluster.local"];
      canivete.kubenix.sharedModules = {
        config,
        helm,
        kubenix,
        name,
        ...
      }: {
        imports = [kubenix.modules.k8s kubenix.modules.helm];
        config._module.args = {inherit canivete flake perSystem system;};
        config.kubernetes.api.resources = pipe config.kubernetes.helm.releases [
          (mapAttrsToList (
            _: release:
              mapAttrs (
                _:
                  mapAttrs (
                    _: resource:
                      mkMerge ([resource] ++ release.overrides)
                  )
              )
              release.extraResources
          ))
          mkMerge
        ];
        config.kubernetes.customTypes.kappconfig = {
          attrName = "kappconfig";
          group = "kapp.k14s.io";
          version = "v1alpha1";
          kind = "Config";
        };
        options.canivete = {
          deploy.fetchKubeconfig = mkOption {
            type = str;
            description = "Script to fetch the kubeconfig of an externally managed Kubernetes cluster. Stdout is the contents of the file";
          };
          script = mkOption {
            type = package;
            description = "Wrapper script";
            default = pkgs.writeShellApplication {
              inherit name;
              text = ''
                # Vals needs to run in project root to access sops config
                cd "$(${getExe pkgs.git} rev-parse --show-toplevel)"

                # Connect to cluster
                KUBECONFIG="$(mktemp)"
                export KUBECONFIG
                trap 'rm -f "$KUBECONFIG"' EXIT
                ${config.canivete.deploy.fetchKubeconfig} >"$KUBECONFIG"

                nix build .#canivete.${system}.kubenix.clusters.${name}.config.kubernetes.resultYAML --no-link --print-out-paths | \
                  xargs cat | \
                  ${getExe pkgs.vals} eval -s -decode-kubernetes-secrets -f - | \
                  ${getExe pkgs.bash} -c "$*"
              '';
            };
          };
        };
        # FIXME why does the template flake say there are multiple definitions of this?!
        options.kubernetes.helm.releases = mkOption {
          type = attrsOf (submodule ({config, ...}: {
            options.extraResources = mkOption {
              default = {};
              type = attrsOf (attrsOf (pkgs.formats.yaml {}).type);
              description = "Extra resources to attach to Helm release; top-level is plural name, like kubernets.resources, for optimal merging";
            };
            # Existing override doesn't provide a default but an override of chart value
            # TODO submit issue report on github.com/hall/kubenix
            config.overrideNamespace = false;
            config.overrides = [
              {metadata.annotations."chart.canivete.app/${config.name}" = "";}
              {metadata.namespace = mkDefault config.namespace;}
            ];
            config.chart = mkDefault (helm.fetch {
              repo = "https://bjw-s-labs.github.io/helm-charts";
              chart = "app-template";
              version = "4.1.1";
              sha256 = "sha256-rwJTCjeC1Z+mvXlwI4EJxONn7ziixOcxruDmD2t+yAM=";
            });
          }));
        };
      };
    };
    options.canivete.kubenix = {
      enable = mkEnableOption "kubenix package builds" // {default = inputs ? kubenix;};
      script = mkOption {
        type = package;
        default = pkgs.writeShellApplication {
          name = "kubenix";
          text = "nix run \".#canivete.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
        };
      };
      sharedModules = mkOption {
        type = deferredModule;
        default = {};
        description = "";
      };
      clusters = mkOption {
        type = attrsOf deferredModule;
        default = {};
        description = "Clusters";
        apply = mapAttrs (
          name: modules:
            import ./ifd.nix (
              inputs.kubenix.evalModules.${system} {
                modules = [modules config.canivete.kubenix.sharedModules {_module.args = {inherit name;};}];
              }
            )
        );
      };
    };
  };
}
