{
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
