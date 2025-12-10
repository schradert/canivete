{
  can,
  config,
  lib,
  perSystem,
  ...
}: {
  options.canivete.crds = can.attrs.submodule "k8s CRD" ({
    config,
    name,
    ...
  }: {
    options = {
      src = can.package "package to pull CRDs from" {};
      name = can.str "name of CRD installation" {default = name;};
      namePrefix = can.str "prefix to apply to CRD modules" {default = "";};
      attrNameOverrides = can.attrs.str "override CRD names" {};
      crds = can.list.str "all the crd files" {internal = true;};

      install = can.enable "install CRDs" {};
      application = can.str "application to install CRDs into" {default = name;};
      prefix = can.str "location in src with CRDs" {default = "";};
      match = can.str "regex match of CRD files" {default = ".+";};
    };
    config.crds =
      can.filesets.everything
      (name: _: lib.hasSuffix ".yaml" name && builtins.match config.match name != null)
      (config.src + "/" + config.prefix);
  });
  config.applications = lib.pipe config.canivete.crds [
    (lib.filterAttrs (_: crd: crd.install))
    (lib.mapAttrsToList (_: crd: {${crd.application}.yamls = map builtins.readFile crd.crds;}))
    lib.mkMerge
  ];
  config.nixidy.applicationImports = lib.flip lib.mapAttrsToList config.canivete.crds (_: crd:
    toString (perSystem.inputs'.nixidy.packages.generators.fromCRD {
      inherit (crd) name src namePrefix crds attrNameOverrides;
    }));
}
