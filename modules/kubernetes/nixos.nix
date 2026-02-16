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
in {
  options.canivete.kubernetes = {
    enable = can.enable "kubernetes as a service" {};
    yaml = can.yaml.option pkgs "settings for config.yaml" {};
  };
  config = lib.mkIf kubernetes.enable (lib.mkMerge [
    {
      canivete.kubernetes.yaml = {
        selinux = true;
        token-file = config.sops.secrets."passwords/k8s-token".path;
      };
      environment.etc."rancher/${k8s}/config.yaml".source = can.yaml.generate pkgs "${k8s}.yaml" kubernetes.yaml;
      environment.systemPackages = [pkgs.${k8s}];
      services.${k8s} = {
        enable = true;
        role = lib.mkDefault "agent";
      };
      sops.secrets."passwords/k8s-token" = {};
      virtualisation.containerd.enable = true;
    }
    (lib.mkIf (cfg.role == "server") {
      canivete.kubernetes.yaml = {
        disable-cloud-controller = true;
        disable-kube-proxy = true;
        disable-scheduler = true;
        etcd-expose-metrics = true;
        tls-san = [domain];
      };
    })
    (lib.mkIf isRoot {services.${k8s}.role = "server";})
    (lib.mkIf (!isRoot) {canivete.kubernetes.yaml.server = "https://${domain}:6443";})
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
