node @ {
  can,
  flake,
  config,
  name,
  ...
}: {
  imports = [./generic.nix];
  options = {
    hostname = can.str "server hostname" {default = name;};
    profiles = can.attrs.submoduleWith "all possible profiles to deploy on node" {inherit flake node;} ./profile.nix;
    profilesOrder = can.opt.list.enum (builtins.attrNames config.profiles) "first profiles to deploy" {};
    canivete.os = can.enum ["nixos" "macos" "windows" "linux" "android"] "node operating system" {default = "nixos";};
    canivete.system = can.str "node architecture" {
      default =
        {
          macos = "aarch64-darwin";
          android = "aarch64-linux";
        }
        .${
          config.canivete.os
        }
        or "x86_64-linux";
    };
  };
}
