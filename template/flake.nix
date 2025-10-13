{
  inputs = {
    # Essentials
    canivete.url = "github:schradert/canivete";
    # flake-parts.url = "github:hercules-ci/flake-parts";
    # canivete.inputs.flake-parts.follows = "flake-parts";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # canivete.inputs.nixpkgs.follows = "nixpkgs";
    # systems.url = "github:nix-systems/default";
    # canivete.inputs.systems.follows = "systems";

    # Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    home-manager.url = "github:nix-community/home-manager";
    nix-on-droid.url = "github:nix-community/nix-on-droid";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    disko.url = "github:nix-community/disko";
    nix-darwin.url = "github:LnL7/nix-darwin";

    # OpenTofu
    terranix.url = "github:terranix/terranix";
    opentofu-registry.url = "github:opentofu/registry";
    opentofu-registry.flake = false;

    # Containers + Kubernetes
    nixidy.url = "github:arnarg/nixidy";
    nixhelm.url = "github:farcaller/nixhelm";
    nix2container.url = "github:nlewo/nix2container";
    # NOTE Arion has no argument to prefer buildLayeredImage when streamLayeredImage doesn't work across systems
    # arion.url = "github:hercules-ci/arion";
    arion.url = "github:schradert/arion/build-layer-image";

    # Development tools
    sops-nix.url = "github:Mic92/sops-nix";
    pre-commit.url = "github:cachix/git-hooks.nix";
    # canivete.inputs.pre-commit.follows = "pre-commit";
    process-compose.url = "github:Platonic-Systems/process-compose-flake";
    services.url = "github:juspay/services-flake";

    # Misc. /h
    dream2nix.url = "github:nix-community/dream2nix";
    flake-schemas.url = "github:DeterminateSystems/flake-schemas";
    nix-flake-schemas.url = "github:DeterminateSystems/nix-src/flake-schemas";
    climod.url = "github:nixosbrasil/climod";
    climod.flake = false;
  };
  # Arguments are:
  # 1. flake-parts module args
  # 2. directories where every .nix file recursively is a flake-parts module
  # 3. root flake-parts module
  outputs = inputs:
    inputs.canivete.lib.mkFlake {inherit inputs;} [] {
      canivete = {
        meta = {
          root = "root";
          domain = "example.com";
          people.me = "username";
          people.users.username.name = "name";
        };
        deploy = {
          nodes."root".profiles.system.canivete.configuration.canivete.kubernetes.enable = true;
          canivete.modules.home-manager.home.stateVersion = "25.05";
          canivete.modules.nixos = {
            boot.loader.systemd-boot.enable = true;
            system.stateVersion = "25.05";
            disko.devices.disk.base = {
              device = "/dev/sda";
              type = "disk";
              content.type = "gpt";
              content.partitions = {
                ESP = {
                  priority = 1;
                  type = "EF00";
                  size = "500M";
                  content.type = "filesystem";
                  content.format = "vfat";
                  content.mountpoint = "/boot";
                };
                root = {
                  priority = 2;
                  end = "-1G";
                  content.type = "filesystem";
                  content.format = "ext4";
                  content.mountpoint = "/";
                };
                swap = {
                  size = "100%";
                  content.type = "swap";
                  content.discardPolicy = "both";
                  content.resumeDevice = true;
                };
              };
            };
          };
        };
        nixidy = {
          k8s = "rke2";
          shared = {charts, ...}: {
            applications.nginx.helm.releases.nginx = {
              chart = charts.bjw-s-labs.app-template;
              values.controllers.nginx.containers.nginx.image = {
                repository = "nginx";
                tag = "1.27.4-bookworm";
              };
            };
          };
        };
        perSystem.canivete = {
          opentofu.workspaces.deploy.kubernetes.cluster = "deploy";
        };
      };
    };
}
