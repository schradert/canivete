{config, ...}: let
  flakeConfig = config;
in {
  canivete.deploy.canivete.modules.nixos = {
    config,
    lib,
    node,
    pkgs,
    ...
  }: let
    inherit (lib) attrValues mkEnableOption mkOption mkIf mkMerge mkDefault types;
    inherit (flakeConfig.canivete.meta) domain;
    cfg = config.canivete.kubernetes;
    cfg_k3s = config.services.k3s;
  in {
    options.canivete.kubernetes = {
      enable = mkEnableOption "kubernetes as a service";
      root = mkEnableOption "root kubernetes server";
      images = mkOption {
        type = types.attrsOf types.package;
        default = {};
        description = "Images to load on root";
      };
      k3s = mkOption {
        inherit (pkgs.formats.yaml {}) type;
        description = "Settings for /etc/rancher/k3s/config.yaml";
        default = {};
      };
    };
    config = mkIf cfg.enable (mkMerge [
      {
        sops.secrets."passwords/k3s-token" = {};
        canivete.kubernetes.k3s = {
          selinux = true;
          token-file = config.sops.secrets."passwords/k3s-token".path;
        };
        environment.etc."rancher/k3s/config.yaml".source = pkgs.writers.writeYAML "k3s.yaml" cfg.k3s;
        environment.systemPackages = [pkgs.k3s];
        services.k3s = {
          enable = true;
          role = mkDefault "agent";
          configPath = "/etc/rancher/k3s/config.yaml";
          gracefulNodeShutdown.enable = true;
        };
        virtualisation.containerd.enable = true;
      }
      (mkIf cfg.root {
        services.k3s = {
          clusterInit = true;
          role = "server";
          images = attrValues cfg.images;
        };
      })
      (mkIf (!cfg.root) {canivete.kubernetes.k3s.server = "https://${domain}:6443";})
      (mkIf (cfg_k3s.role == "server") {
        canivete.kubernetes.k3s = {
          # Barebones
          disable = ["traefik" "servicelb" "local-storage" "metrics-server" "coredns"];
          flannel-backend = "none";
          disable-kube-proxy = true;
          disable-network-policy = true;
          disable-helm-controller = true;
          # Server only
          etcd-expose-metrics = true;
          tls-san = [domain];
        };
      })
    ]);
  };
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (lib) any attrValues filterAttrs mkIf pipe;
    hasKubernetesNode = pipe flakeConfig.canivete.deploy.nodes [
      (filterAttrs (_: node: node.canivete.os == "nixos"))
      attrValues
      (any (cfg: cfg.profiles.system.canivete.configuration.config.canivete.kubernetes.enable))
    ];
  in {
    canivete = mkIf (hasKubernetesNode && config.canivete.opentofu.enable) {opentofu.workspaces.deploy.passwords.k3s-token.length = 21;};
  };
}
