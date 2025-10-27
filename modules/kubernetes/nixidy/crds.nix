{
  canivete,
  config,
  lib,
  perSystem,
  ...
}: let
  inherit (lib) types;
  inherit (types) str;
  mkTypeOption = type: canivete.mkOverrideOption {inherit type;};
in {
  options.dotfiles.crds = lib.mkOption {
    default = {};
    type = types.attrsOf (types.submodule ({
      config,
      name,
      ...
    }: {
      options = {
        src = mkTypeOption types.package {};
        name = mkTypeOption str {default = name;};
        namePrefix = mkTypeOption str {default = "";};
        attrNameOverrides = mkTypeOption (types.attrsOf str) {default = {};};
        crds = mkTypeOption (types.listOf str) {internal = true;};

        install = lib.mkEnableOption "install CRDs";
        application = mkTypeOption str {default = name;};
        prefix = mkTypeOption str {default = "";};
        match = mkTypeOption str {default = ".+";};
      };
      config.crds = canivete.filesets.everything (name: _: lib.hasSuffix ".yaml" name && builtins.match config.match name != null) (config.src + "/" + config.prefix);
    }));
  };
  config.applications = lib.pipe config.dotfiles.crds [
    (lib.filterAttrs (_: crd: crd.install))
    (lib.mapAttrsToList (_: crd: {${crd.application}.yamls = map builtins.readFile crd.crds;}))
    lib.mkMerge
  ];
  config.nixidy.applicationImports = lib.flip lib.mapAttrsToList config.dotfiles.crds (_: crd:
    toString (perSystem.inputs'.nixidy.packages.generators.fromCRD {
      inherit (crd) name src namePrefix crds attrNameOverrides;
    }));
}
