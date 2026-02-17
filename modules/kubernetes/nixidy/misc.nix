{
  can,
  config,
  lib,
  perSystem,
  ...
}: {
  options.build.scripts.nixidy = can.package "nixidy executable" {internal = true;};
  config.build.scripts.nixidy = perSystem.inputs'.nixidy.packages.default;
  config.nixidy = {
    target.branch = lib.mkDefault "trunk";
    target.rootPath = lib.mkOverride 500 "./generated/nixidy/${config.nixidy.env}";
    defaults.helm.transformer = builtins.map (lib.kube.removeLabels [
      # Helm chart versions are just not necessary
      "app.kubernetes.io/version"
      "helm.sh/chart"
    ]);
  };
}
