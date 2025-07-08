{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) attrValues flip pipe importJSON toList mkIf getExe mkOption types elem getName;
  inherit (types) listOf str attrsOf anything;
in {
  # TODO options for overlays (from options.flake.overlays doesn't work?)
  # TODO nixpkgs config options
  options.canivete.pkgs = {
    allowUnfree = mkOption {
      type = listOf str;
      default = [];
      description = "Package names to ignore because unfree";
    };
    config = mkOption {
      type = attrsOf anything;
      default = {};
      description = "Nixpkgs configuration (i.e. allowUnfreePredicate, etc.)";
    };
  };
  config.canivete.pkgs.config = mkIf (config.canivete.pkgs.allowUnfree != []) {
    allowUnfreePredicate = pkg: elem (getName pkg) config.canivete.pkgs.allowUnfree;
  };
  config.perSystem = {
    pkgs,
    system,
    ...
  }: {
    options.canivete.pkgs.pkgs = mkOption {};
    config.canivete.pkgs.pkgs = pkgs;
    config._module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.canivete.pkgs) config;
      overlays =
        attrValues inputs.self.overlays
        ++ toList (final: _: {
          fromYAML = flip pipe [
            (file: "${final.yq}/bin/yq '.' ${file} > $out")
            (final.runCommand "from-yaml" {})
            importJSON
          ];
          execBash = cmd: [(getExe final.bash) "-c" cmd];
          wrapProgram = srcs: name: exe: args: overrides:
            final.symlinkJoin ({
                inherit name;
                buildInputs = [final.makeWrapper];
                paths = toList srcs;
                postBuild =
                  if name == exe
                  then "wrapProgram \"$out/bin/${exe}\" ${args}"
                  else "makeWrapper \"$out/bin/${exe}\" \"$out/bin/${name}\" ${args}";
                meta.mainProgram = name;
              }
              // overrides);
          wrapFlags = pkg: args: final.wrapProgram pkg pkg.name pkg.name args {};
          patchOut = pkg: cmd:
            final.runCommand "${pkg.name}-patched" {} ''
              cp -a ${pkg} $out
              chmod -R u+w $out
              ${cmd}
            '';
        });
    };
  };
}
