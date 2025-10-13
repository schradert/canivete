{
  config,
  flake,
  lib,
  nixidy,
  node,
  pkgs,
  ...
}: let
  inherit (config.canivete) kubernetes;
  inherit (flake.config.canivete.meta) domain root;
  inherit (lib) mkIf mkMerge;
  inherit (nixidy.config) k8s;
  cfg = config.services.${k8s};
  isRoot = node.name == root;
in {
  options.canivete.kubernetes = {
    enable = lib.mkEnableOption "kubernetes as a service";
    yaml = lib.mkOption {
      inherit (pkgs.formats.yaml {}) type;
      description = "Settings for config.yaml";
      default = {};
    };
  };
  config = mkIf kubernetes.enable (mkMerge [
    {
      canivete.kubernetes.yaml = {
        selinux = true;
        token-file = config.sops.secrets."passwords/k8s-token".path;
      };
      environment.etc."rancher/${k8s}/config.yaml".source = pkgs.writers.writeYAML "${k8s}.yaml" kubernetes.yaml;
      environment.systemPackages = [pkgs.${k8s}];
      services.${k8s} = {
        enable = true;
        role = lib.mkDefault "agent";
      };
      sops.secrets."passwords/k8s-token" = {};
      virtualisation.containerd.enable = true;
    }
    (mkIf (cfg.role == "server") {
      canivete.kubernetes.yaml = {
        disable-cloud-controller = true;
        disable-kube-proxy = true;
        disable-scheduler = true;
        etcd-expose-metrics = true;
        tls-san = [domain];
      };
    })
    (mkIf isRoot {services.${k8s}.role = "server";})
    (mkIf (!isRoot) {canivete.kubernetes.yaml.server = "https://${domain}:6443";})
    (mkIf (k8s == "k3s") (mkMerge [
      {services.k3s.gracefulNodeShutdown.enable = true;}
      (mkIf isRoot {services.k3s.clusterInit = true;})
      (mkIf (cfg.role == "server") {
        canivete.kubernetes.yaml = {
          disable = ["traefik" "servicelb" "local-storage" "metrics-server" "coredns"];
          disable-network-policy = true;
          disable-helm-controller = true;
          flannel-backend = "none";
        };
      })
    ]))
    (mkIf (k8s == "rke2" && cfg.role == "server") {
      canivete.kubernetes.k3s = {
        disable = ["rke2-coredns" "rke2-ingress-nginx" "rke2-metrics-server"];
        cni = "none";
      };
    })
  ]);
}
