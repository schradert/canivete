{
  lib,
  nixidy,
  pkgs,
  ...
}: {
  _module.args.charts = lib.mergeAttrsList [
    (inputs.nixhelm.chartsDerivations.${pkgs.system} or {})
    nixidy.charts
  ];
}
