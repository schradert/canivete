{
  config,
  lib,
  ...
}: {
  nixidy.appOfApps.namespace = "cicd";
  nixidy.applicationImports = [
    (_: {
      defaults = lib.toList {
        kind = "Namespace";
        default.metadata.annotations."argocd.argoproj.io/sync-options" = lib.mkDefault "Prune=confirm";
      };
    })
  ];
  applications.${config.nixidy.appOfApps.name} = {
    defaults = lib.toList {
      kind = "Namespace";
      default.metadata.annotations."argocd.argoproj.io/sync-options" = "Prune=false";
    };
  };
}
