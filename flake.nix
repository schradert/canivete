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
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      canivete,
      lib,
      ...
    }: {
      imports = [./modules];
      flake.lib = canivete;
      # TODO what about directories? how should these be handled? use every nix file?
      flake.flakeModules = let
        inherit (builtins) baseNameOf map match head listToAttrs;
        inherit (lib) flip nameValuePair pipe;
      in
        pipe ./modules [
          canivete.filesets.nix.files
          (map (file:
            flip nameValuePair file (pipe file [
              baseNameOf
              (match "^(.+)\.nix$")
              head
            ])))
          listToAttrs
        ];
      # TODO add WAYYY more templates
      flake.templates.default = {
        path = ./template;
        description = "Basic canivete template";
      };
      perSystem.canivete.pre-commit.languages.shell.enable = true;
    });
}
