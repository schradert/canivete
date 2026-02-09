{
  can,
  config,
  inputs,
  lib,
  system,
  ...
}: let
  inherit (config.canivete.deploy) nodes;
  inherit (config.canivete.deploy.canivete) flakes modules;
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
in {
  options.deploy = can.raw "deploy-rs" {};
  config = lib.mkMerge [
    {
      _module.args.withSystem = system: func: func {pkgs = inputs.nixpkgs.legacyPackages.${system};};
    }
    (lib.mkIf (nodes != {}) {
      deploy = lib.filterAttrsRecursive (name: value: name != "canivete" && value != null) config.canivete.deploy;
      enterTest = lib.getExe (flakes.deploy.lib.${system}.deployChecks config.deploy);
      packages = [flakes.deploy.packages.${system}.default];
      # FIXME how are these going to be built with deploy-rs?
      # machines = lib.mkMerge [
      #   (lib.mkIf (nixosConfigurations != {}) (builtins.mapAttrs (_: cfg: {nixos = cfg;}) nixosConfigurations))
      #   (lib.mkIf (darwinConfigurations != {}) (builtins.mapAttrs (_: cfg: {nix-darwin = cfg;}) darwinConfigurations))
      #   (lib.mkIf (nixOnDroidConfigurations != {}) (builtins.mapAttrs (_: cfg: {nix-on-droid = cfg;}) nixOnDroidConfigurations))
      #   (lib.mkIf (homeManagerConfigurations != {}) (builtins.mapAttrs (_: cfg: {nixos = cfg;}) homeManagerConfigurations))
      # ];
    })
  ];
}
