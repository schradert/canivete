{
  can,
  flake,
  nixidy,
  pkgs,
  ...
}: let
  inherit (flake.config.canivete.meta) root;
  cmds.k3s = "k3s kubectl config view --raw";
  cmds.rke2 = "cat /etc/rancher/rke2/rke2.yaml";
in {
  options.build.scripts.kubeconfig = can.package "command to connect cluster" {internal = true;};
  config.build.scripts.kubeconfig = pkgs.writeShellApplication {
    name = "kubeconfig";
    runtimeInputs = with pkgs; [openssh toybox];
    # TODO fix these hardcoded values
    text = ''
      KUBECONFIG="$(mktemp)"
      export KUBECONFIG
      trap 'rm -f "$KUBECONFIG"' EXIT
      ssh ${root} sudo ${cmds.${nixidy.config.k8s}} | \
        sed 's/127\.0\.0\.1/${root}/' \
        >"$KUBECONFIG"
      "''${@}"
    '';
  };
}
