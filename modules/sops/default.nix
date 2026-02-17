{
  can,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.canivete.meta.people) me;
  inherit (config.canivete) sops;
  inherit (inputs) sops-nix;
  getFilepathHomeRelative = home: pkgs: let
    directoryConfig =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support"
      else ".config";
  in "${home}/${directoryConfig}/sops/age/keys.txt";
in {
  options.canivete.sops = {
    enable = can.enable "SOPS" {default = inputs ? sops-nix;};
    directory = can.str "path relative to project root to store SOPS secrets" {default = ".canivete/sops";};
    default = can.str "path relative to sops directory for storing SOPS secrets by default in YAML" {
      default = "default.yaml";
      apply = can.prefix "${sops.directory}/";
    };
  };
  config = lib.mkIf sops.enable {
    canivete.deploy.canivete.modules = {
      # TODO should I use age.sshKeyPaths + age.generateKey
      shared.sops.defaultSopsFile = inputs.self + "/" + sops.default;
      home-manager = {
        config,
        pkgs,
        ...
      }: {
        imports = [sops-nix.homeManagerModules.sops];
        sops.age.keyFile = getFilepathHomeRelative config.home.homeDirectory pkgs;
      };
      nixos = {
        config,
        pkgs,
        ...
      }: {
        imports = [sops-nix.nixosModules.sops];
        sops.age.keyFile = getFilepathHomeRelative config.users.users.root.home pkgs;
      };
      darwin = {pkgs, ...}: {
        imports = [sops-nix.darwinModules.sops];
        sops.age.keyFile = getFilepathHomeRelative "/Users/${me}" pkgs;
      };
    };
    perSystem = {
      config,
      pkgs,
      ...
    }: {
      imports = [./opentofu.nix];
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
      config.canivete.devenv.modules = [
        {
          packages = [config.canivete.sops.package];
          git-hooks.excludes = ["${sops.directory}/.+"];
          scripts.sops-setup.exec = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- \"$@\"";
        }
      ];
    };
  };
}
