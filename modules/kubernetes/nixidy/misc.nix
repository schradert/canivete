{
  config,
  lib,
  perSystem,
  ...
}: {
  options.build.scripts.nixidy = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Nixidy executable";
  };
  config.build.scripts.nixidy = perSystem.inputs'.nixidy.packages.default;
  config.nixidy.target.rootPath = "./generated/nixidy/${config.nixidy.env}";
  config.nixidy.defaults.helm.transformer = builtins.map (lib.kube.removeLabels [
    # Helm chart versions are just not necessary
    "app.kubernetes.io/version"
    "helm.sh/chart"
  ]);
}
