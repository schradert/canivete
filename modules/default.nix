{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) getAttr mapAttrs mergeAttrsList mkDefault;
in {
  imports = [
    ./deploy
    ./kubernetes
    ./opentofu
    ./scripts
    ./sops

    ./arion.nix
    ./canivete.nix
    ./climod.nix
    ./devShells.nix
    ./dream2nix.nix
    ./just.nix
    ./meta.nix
    ./nix2container.nix
    ./pkgs.nix
    ./pre-commit.nix
    ./processes.nix
    ./schemas.nix
  ];
  systems = mkDefault (import inputs.systems);

  # Expose everything canivete to flake top level
  flake.canivete = mergeAttrsList [
    (config.canivete or {})
    (mapAttrs (_: getAttr "canivete") config.allSystems)
    {inherit inputs;}
  ];
}
