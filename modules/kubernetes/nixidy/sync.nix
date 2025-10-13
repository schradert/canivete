{
  nixidy.applicationImports = [
    (_: {
      syncPolicy.syncOptions = {
        applyOutOfSyncOnly = true;
        pruneLast = true;
        serverSideApply = true;
        failOnSharedResource = true;
      };
    })
  ];
  nixidy.defaults.syncPolicy.autoSync = {
    enable = true;
    prune = true;
    selfHeal = true;
  };
}
