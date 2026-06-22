{
  can,
  config,
  flake,
  lib,
  node,
  pkgs,
  ...
}: let
  inherit (config.canivete) kubernetes;
  inherit (flake.config.canivete) meta nixidy;
  inherit (meta) domain root;
  inherit (nixidy) k8s;
  cfg = config.services.${k8s};
  isRoot = node.name == root;
  # k3s serves the supervisor (node registration) on 6443; rke2 uses 9345.
  supervisorPort =
    if k8s == "rke2"
    then 9345
    else 6443;
in {
  options.canivete.kubernetes = {
    enable = can.enable "kubernetes as a service" {};
    yaml = can.yaml.option pkgs "settings for config.yaml" {};
    serverEndpoint = can.str "host non-root nodes register against; point at a load balancer for an HA control plane" {default = domain;};
  };
  config = lib.mkIf kubernetes.enable (lib.mkMerge [
    {
      canivete.kubernetes.yaml.selinux = true;
      environment.etc."rancher/${k8s}/config.yaml".source = can.yaml.generate pkgs "${k8s}.yaml" kubernetes.yaml;
      environment.systemPackages = [pkgs.${k8s}];
      services.${k8s} = {
        enable = true;
        role = lib.mkDefault "agent";
      };
      virtualisation.containerd.enable = true;
    }
    (lib.mkIf (cfg.role == "server") {
      # mkDefault so downstream can override per-key (re-enable the scheduler,
      # extend tls-san, etc.) without mkForce.
      canivete.kubernetes.yaml = {
        disable-cloud-controller = lib.mkDefault true;
        disable-kube-proxy = lib.mkDefault true;
        disable-scheduler = lib.mkDefault true;
        etcd-expose-metrics = lib.mkDefault true;
        tls-san = lib.mkDefault [domain];
      };
    })
    (lib.mkIf isRoot {services.${k8s}.role = "server";})
    (lib.mkIf (!isRoot) {canivete.kubernetes.yaml.server = "https://${kubernetes.serverEndpoint}:${toString supervisorPort}";})
    (lib.mkIf (k8s == "k3s") (lib.mkMerge [
      {services.k3s.gracefulNodeShutdown.enable = true;}
      (lib.mkIf isRoot {services.k3s.clusterInit = true;})
      (lib.mkIf (cfg.role == "server") {
        canivete.kubernetes.yaml = {
          disable = ["traefik" "servicelb" "local-storage" "metrics-server" "coredns"];
          disable-network-policy = true;
          disable-helm-controller = true;
          flannel-backend = "none";
        };
      })
    ]))
    (lib.mkIf (k8s == "rke2" && cfg.role == "server") {
      canivete.kubernetes.yaml = {
        disable = ["rke2-coredns" "rke2-ingress-nginx" "rke2-metrics-server"];
        cni = "none";
      };
    })
  ]);
}
