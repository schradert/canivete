{
  can,
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./deploy
    ./kubernetes
    ./opentofu
    ./pkgs
    ./sops

    ./devenv.nix
    ./meta.nix
  ];
  systems = lib.mkDefault (import inputs.systems);
  perSystem._module.args = {inherit can;};

  # Expose everything canivete to flake top level
  flake.canivete = lib.mergeAttrsList [
    (config.canivete or {})
    (builtins.mapAttrs (_: builtins.getAttr "canivete") config.allSystems)
    {inherit inputs;}
  ];
}
