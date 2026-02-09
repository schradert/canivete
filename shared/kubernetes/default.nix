top @ {
  can,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.canivete) nixidy;
in {
  options.canivete.nixidy = can.submodule "nixidy" (nixidy: {
    options = {
      enable = can.enable "nixidy" {default = inputs ? nixidy;};
      shared = can.module "shared modules" {};
      args = can.attrs.anything "nixidy args" {};
      envs = can.attrs.module "environment configs" {};
      charts = can.attrs.anything "nixidy charts" {};
      libOverlay = can.overlay "extra lib functions" {};
      k8s = can.enum ["k3s" "rke2"] "kubernetes distribution" {default = "k3s";};
    };
    config = {
      args = {inherit can top nixidy;};
      shared = ./nixidy;
      envs.prod = {};
    };
  });
  config.canivete.deploy.canivete.modules.nixos = ./nixos.nix;
}
