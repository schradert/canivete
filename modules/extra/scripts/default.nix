{
  perSystem = {
    lib,
    pkgs,
    ...
  }: {
    options.canivete.scripts = lib.mkOption {
      default = {};
      description = "Scripts!";
      type = with lib.types; attrsOf package;
    };
    config.canivete.scripts.utils = pkgs.writeShellScriptBin "canivete" ./utils.sh;
  };
}
