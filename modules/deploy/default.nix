flake @ {
  can,
  config,
  inputs,
  lib,
  # deadnix: skip
  withSystem,
  ...
}: let
  inherit (config.canivete.meta) people;
  inherit (config.canivete.deploy) nodes;
  inherit (config.canivete.deploy.canivete) flakes modules;
in {
  imports = [./opentofu.nix];
  options.canivete.deploy = can.submodule "deploy-rs with a twist" {
    imports = [./generic.nix];
    options = {
      nodes = can.attrs.submoduleWith "nodes to deploy profiles to" {inherit flake;} ./node.nix;
      canivete.flakes = {
        deploy = can.flake inputs "deploy-rs" {};
        nixos = can.flake inputs "nixpkgs" {};
        darwin = can.flake inputs "nix-darwin" {};
        droid = can.flake inputs "nix-on-droid" {};
        home-manager = can.flake inputs "home-manager" {};
        anywhere = can.flake inputs "nixos-anywhere" {};
        disko = can.flake inputs "disko" {};
      };
      canivete.modules = {
        home-manager = can.module "home-manager modules" {};
        nixos = can.module "nixos modules" {};
        darwin = can.module "nix-darwin modules" {};
        droid = can.module "nix-on-droid modules" {};
        system = can.module "shared modules for system deployment (i.e. nixos, darwin, droid)" {};
        shared = can.module "shared modules for all deployments (including home-manager)" {};
      };
    };
    config = {
      canivete.modules = let
        hostnameModule = {node, ...}: {networking.hostName = node.config.hostname;};
      in {
        shared = {pkgs, ...}: {
          # Must instantiate within module (i.e. can't pass through specialArgs because deploy-rs eagerly evaluates)
          _module.args.perSystem = flake.withSystem pkgs.stdenv.hostPlatform.system lib.id;
        };
        home-manager = {profile, ...}: {
          imports = [modules.shared];
          config = lib.mkIf (profile.config.canivete.type == "home-manager") {
            home.username = lib.mkDefault profile.name;
          };
        };
        system = lib.mkMerge [
          ({node, ...}: {
            imports = [modules.shared];
            nixpkgs.hostPlatform = node.config.canivete.system;
          })
          (lib.mkIf (flakes.home-manager != null) (systemConfiguration @ {
            node,
            perSystem,
            # deadnix: skip
            pkgs,
            profile,
            ...
          }: {
            home-manager = {
              extraSpecialArgs = {inherit can flake node perSystem profile systemConfiguration;};
              sharedModules = [modules.home-manager];
              users = builtins.mapAttrs (username: _: {home.username = lib.mkDefault username;}) people.users;
            };
          }))
        ];
        nixos = lib.mkMerge [
          {
            imports = [hostnameModule modules.system];
            # "root" is a special user name that will be excluded from normal users
            users.users = lib.flip builtins.mapAttrs (removeAttrs people.users ["root"]) (username: person: {
              isNormalUser = true;
              home = "/home/${username}";
              description = person.name;
              extraGroups = ["tty"] ++ (lib.optional (username == people.me) "wheel");
            });
          }
          (lib.mkIf (flakes.disko != null) flakes.disko.nixosModules.default)
          (lib.mkIf (flakes.home-manager != null) ({utils, ...}: {
            imports = [flakes.home-manager.nixosModules.home-manager];
            home-manager.extraSpecialArgs = {inherit utils;};
          }))
        ];
        droid = modules.system;
        darwin = lib.mkMerge [
          {
            imports = [hostnameModule modules.system];
            users.users = lib.flip builtins.mapAttrs people.users (username: person: {
              home = "/Users/${username}";
              description = person.name;
            });
          }
          (lib.mkIf (flakes.home-manager != null) flakes.home-manager.darwinModules.home-manager)
        ];
      };
    };
  };
  config = let
    typeNodes = type: let
      isType = lib.filterAttrs (_: profile: profile.canivete.type == type);
      typeProfiles = funcs: node: lib.pipe node.profiles ([isType builtins.attrValues] ++ funcs);
    in
      lib.pipe nodes [
        # TODO what happens if there are multiple "system"-type configurations?!
        (lib.filterAttrs (_: typeProfiles [builtins.length (l: l == 1)]))
        (builtins.mapAttrs (_: typeProfiles [builtins.head (lib.getAttrFromPath ["canivete" "configuration"])]))
      ];
    nixosConfigurations = typeNodes "nixos";
    darwinConfigurations = typeNodes "darwin";
    nixOnDroidConfigurations = typeNodes "droid";
    homeManagerConfigurations = typeNodes "home-manager";
  in
    lib.mkIf (nodes != {}) {
      flake = lib.mkMerge [
        {deploy = lib.filterAttrsRecursive (name: value: name != "canivete" && value != null) config.canivete.deploy;}
        (lib.mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
        (lib.mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
        (lib.mkIf (nixOnDroidConfigurations != {}) {inherit nixOnDroidConfigurations;})
        (lib.mkIf (homeManagerConfigurations != {}) {inherit homeManagerConfigurations;})
      ];
      perSystem = {system, ...}: {
        checks = flakes.deploy.lib.${system}.deployChecks inputs.self.deploy;
        canivete.devenv.shells.default.packages = [flakes.deploy.packages.${system}.default];
      };
    };
}
