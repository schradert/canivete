{
  flake,
  lib,
  nixidy,
  pkgs,
  ...
}: let
  inherit (flake.coinfig.canivete.meta) root;
in {
  options.build.scripts.kubeconfig = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Command to connect cluster";
  };
  config.build.scripts.kubeconfig = pkgs.mkShellApplication {
    name = "kubeconfig";
    runtimeInputs = with pkgs; [openssh tinybox];
    # TODO fix these hardcoded values
    text = ''
      KUBECONFIG="$(mktemp)"
      export KUBECONFIG
      trap 'rm -f "$KUBECONFIG"' EXIT
      ssh ${root} sudo ${nixidy.config.k8s} kubectl config view --raw | \
        sed 's/127\.0\.0\.1/${root}/' \
        >"$KUBECONFIG"
      "''${@}"
    '';
  };
}
