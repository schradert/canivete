{
  can,
  config,
  inputs,
  ...
}: {
  config.perSystem = {
    pkgs,
    system,
    ...
  }: {
    options.canivete.pkgs.pkgs = can.anything "exposes upstream packages to flake" {};
    config.canivete.pkgs.pkgs = pkgs;
    config._module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.canivete.pkgs) config;
      overlays = [config.canivete.pkgs.overlays];
    };
  };
}
