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
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({canivete, ...}: {
      imports = [./modules];
      flake.lib = canivete;
      flake.templates.default.path = ./template;
      perSystem.canivete.devenv.shells.default.languages.shell.enable = true;
    });
}
