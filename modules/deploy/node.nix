flake @ {
  canivete,
  lib,
  ...
}: let
  inherit (canivete) mkNullableOption mkSystemOption;
  inherit (lib) attrNames mkOption types;
  inherit (types) attrsOf enum listOf str submodule;
in
  node @ {
    config,
    name,
    ...
  }: {
    imports = [(import ./generic.nix flake)];
    options = {
      hostname = mkOption {
        type = str;
        default = name;
        description = "Server hostname";
      };
      profiles = mkOption {
        type = attrsOf (submodule {
          imports = [(import ./profile.nix flake)];
          _module.args = {inherit node;};
        });
        default = {};
        description = "All possible profiles to deploy on node";
      };
      profilesOrder = mkNullableOption (listOf (enum (attrNames config.profiles))) {description = "First profiles to deploy";};
      canivete.os = mkOption {
        type = enum ["nixos" "macos" "windows" "linux" "android"];
        default = "nixos";
        description = "Node operating system";
      };
      canivete.system = mkSystemOption {
        default =
          {
            macos = "aarch64-darwin";
            android = "aarch64-linux";
          }
          .${config.canivete.os}
          or "x86_64-linux";
      };
    };
  }
