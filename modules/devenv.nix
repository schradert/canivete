{
  can,
  inputs,
  lib,
  ...
}: {
  imports = [(inputs.devenv.flakeModule or {})];
  config = lib.mkIf (inputs ? devenv) {
    perSystem.imports = [(lib.mkAliasOptionModule ["canivete" "devenv"] ["devenv"])];
    perSystem.canivete.devenv.modules = [
      {
        imports = [../shared/devenv.nix];
        _module.args = {inherit can;};
        git-hooks.excludes = [".canivete"];
      }
    ];
  };
}
