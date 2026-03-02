{
  can,
  config,
  lib,
  pkgs,
  ...
}: let
  getGVKN = o: builtins.concatStringsSep "/" [o.apiVersion o.kind o.metadata.name];
in {
  options.build.scripts.bootstrap = can.package "command to bootstrap cluster" {internal = true;};
  config = {
    nixidy.applicationImports = [
      (_: {
        options.canivete.bootstrap = {
          enable = can.enable "importing resources into cluster bootstrap" {};
          exclude = can.list.str "resources to exclude from bootstrap" {};
        };
      })
    ];
    applications.__bootstrap.objects = lib.pipe config.nixidy.publicApps [
      (builtins.filter (name: name != config.nixidy.appOfApps.name))
      (builtins.map (name: config.applications.${name}))
      (builtins.filter (app: app.canivete.bootstrap.enable))
      (builtins.map (app: builtins.filter (obj: !(builtins.elem (getGVKN obj) app.canivete.bootstrap.exclude)) app.objects))
      lib.flatten
    ];
    build.scripts.bootstrap = pkgs.writeShellApplication {
      # Vals needs to run in the project root to read SOPS
      name = "nixidy-bootstrap-${config.nixidy.env}";
      runtimeInputs = [
        pkgs.git
        config.build.scripts.nixidy
        pkgs.vals
        config.build.scripts.kubeconfig
        pkgs.kapp
      ];
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        nixidy bootstrap .#${config.nixidy.env} | \
          vals eval -s -decode-kubernetes-secrets -f - | \
          kubeconfig kapp deploy --yes --diff-changes --app bootstrap --file -
      '';
    };
  };
}
