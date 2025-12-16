{
  description = "Useful flake-parts modules";
  inputs = {
    # TODO is it possible to introduce new inputs in repos and check for those in modules?
    # something like canivete.inputs.deploy-rs.url = "github:serokell/deploy-rs"; without top-level here

    # Essential
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # Development
    devenv.url = "github:cachix/devenv";
  };
  outputs = inputs: let
    specialArgs.can = import ./lib.nix inputs.nixpkgs.lib;
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs specialArgs;} ({
      can,
      lib,
      ...
    }: {
      imports = [./modules];
      flake = {
        inherit can;
        templates.default.path = ./template;
        lib.mkFlake = args: module: let
          _args = lib.mergeAttrs (builtins.removeAttrs args ["everything"]) {
            inputs = inputs // args.inputs;
            specialArgs = specialArgs // (args.specialArgs or {});
          };
          imports = lib.concat [module ./modules] (can.filesets.nix.everything (args.everything or []));
        in
          inputs.flake-parts.lib.mkFlake _args {inherit imports;};
      };
      perSystem.canivete.devenv.shells.default.languages.shell.enable = true;
    });
}
