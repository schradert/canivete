{
  can,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.canivete) sops;
  getFilepathHomeRelative = home: pkgs: let
    directoryConfig =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support"
      else ".config";
  in "${home}/${directoryConfig}/sops/age/keys.txt";
in {
  options.canivete.sops = {
    package = lib.mkPackageOption pkgs "sops" {};
    scripts.setup = can.package "bootstrap repository sops" {
      default = pkgs.writeShellApplication {
        name = "sops-setup";
        runtimeInputs = with pkgs; [openssh age ssh-to-age gum];
        runtimeEnv.CANIVETE_SOPS_AGE_KEY_FILE = getFilepathHomeRelative pkgs;
        text = builtins.readFile ./setup.sh;
      };
    };
  };
  config = {
    packages = [sops.package];
    git-hooks.excludes = ["${sops.directory}/.+"];
    # FIXME get this working
    # scripts.sops-setup.exec = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- \"$@\"";
  };
}
