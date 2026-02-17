{
  can,
  flake,
  nixidy,
  pkgs,
  ...
}: let
  inherit (flake.config.canivete.meta) root;
in {
  options.build.scripts.kubeconfig = can.package "command to connect cluster" {internal = true;};
  config.build.scripts.kubeconfig = pkgs.writeShellApplication {
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
