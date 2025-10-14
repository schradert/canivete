{
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./deploy
    ./kubernetes
    ./opentofu
    ./sops

    ./canivete.nix
    ./devenv.nix
    ./meta.nix
    ./pkgs.nix
  ];
  systems = lib.mkDefault (import inputs.systems);

  # Expose everything canivete to flake top level
  flake.canivete = lib.mergeAttrsList [
    (config.canivete or {})
    (builtins.mapAttrs (_: builtins.getAttr "canivete") config.allSystems)
    {inherit inputs;}
  ];
}
