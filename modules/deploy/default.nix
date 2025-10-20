flake @ {
  canivete,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (canivete) mkFlakeOption mkModuleOption;
  inherit (config.canivete.meta) people;
  inherit (config.canivete.deploy) nodes;
  inherit (config.canivete.deploy.canivete) flakes modules;
  inherit (lib) filterAttrsRecursive flip mapAttrs mkIf mkMerge mkOption optional types;
  inherit (types) attrsOf submodule;
in {
  imports = [./opentofu.nix];
  options.canivete.deploy = mkOption {
    type = submodule {
      imports = [(import ./generic.nix flake)];
      options.nodes = mkOption {
        type = attrsOf (submodule (import ./node.nix flake));
        default = {};
        description = "Nodes to deploy profiles to";
      };
      options.canivete = {
        flakes = {
          deploy = mkFlakeOption "deploy-rs" {};
          nixos = mkFlakeOption "nixpkgs" {};
          darwin = mkFlakeOption "nix-darwin" {};
          droid = mkFlakeOption "nix-on-droid" {};
          home-manager = mkFlakeOption "home-manager" {};
          anywhere = mkFlakeOption "nixos-anywhere" {};
          disko = mkFlakeOption "disko" {};
        };
        modules = {
          home-manager = mkModuleOption {};
          nixos = mkModuleOption {};
          darwin = mkModuleOption {};
          droid = mkModuleOption {};
          system = mkModuleOption {};
          shared = mkModuleOption {};
        };
      };
      config.canivete.modules = let
        hostnameModule = {node, ...}: {networking.hostName = node.config.hostname;};
      in {
        system = mkMerge [
          modules.shared
          # TODO can I do this for other systems too?
          (mkIf (flakes.home-manager != null) (systemConfiguration @ {
            node,
            perSystem,
            # deadnix: skip
            pkgs,
            profile,
            ...
          }: {
            home-manager.extraSpecialArgs = {inherit canivete flake node perSystem profile systemConfiguration;};
            home-manager.users = mapAttrs (username: _: {home = {inherit username;};}) people.users;
            home-manager.sharedModules = [modules.home-manager];
          }))
        ];
        home-manager.imports = [modules.shared];
        nixos = mkMerge [
          {
            imports = [
              hostnameModule
              modules.system
            ];
            users.users = flip mapAttrs people.users (username: person: {
              isNormalUser = true;
              home = "/home/${username}";
              description = person.name;
              extraGroups = ["tty"] ++ (optional (username == people.me) "wheel");
            });
          }
          (mkIf (flakes.disko != null) flakes.disko.nixosModules.default)
          # TODO can I do this for other systems too?
          (mkIf (flakes.home-manager != null) ({utils, ...}: {
            imports = [flakes.home-manager.nixosModules.home-manager];
            home-manager.extraSpecialArgs = {inherit utils;};
          }))
        ];
        droid.imports = [modules.system];
        darwin = mkMerge [
          hostnameModule
          modules.system
          (mkIf (flakes.home-manager != null) flakes.home-manager.darwinModules.home-manager)
        ];
      };
    };
    default = {};
    description = "Deployment with deploy-rs and nixos-anywhere";
  };
  config = let
    typeNodes = type: let
      inherit (lib) attrValues filterAttrs getAttrFromPath head length mapAttrs pipe;
      typeProfiles = funcs: node: pipe node.profiles ([(filterAttrs (_: profile: profile.canivete.type == type)) attrValues] ++ funcs);
    in
      pipe nodes [
        # TODO what happens if there are multiple "system"-type configurations?!
        (filterAttrs (_: typeProfiles [length (l: l == 1)]))
        (mapAttrs (_: typeProfiles [head (getAttrFromPath ["canivete" "configuration"])]))
      ];
    nixosConfigurations = typeNodes "nixos";
    darwinConfigurations = typeNodes "darwin";
    nixOnDroidConfigurations = typeNodes "droid";
    homeManagerConfigurations = typeNodes "home-manager";
  in
    mkIf (nodes != {}) {
      flake = mkMerge [
        {deploy = filterAttrsRecursive (name: value: name != "canivete" && value != null) config.canivete.deploy;}
        (mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
        (mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
        (mkIf (nixOnDroidConfigurations != {}) {inherit nixOnDroidConfigurations;})
        (mkIf (homeManagerConfigurations != {}) {inherit homeManagerConfigurations;})
      ];
      perSystem = {system, ...}: {
        checks = flakes.deploy.lib.${system}.deployChecks inputs.self.deploy;
      };
    };
}
