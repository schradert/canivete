{
  can,
  config,
  inputs,
  lib,
  ...
}: {
  # TODO nixpkgs config options
  options.canivete.pkgs = can.submodule "high-level pkgs configuration" ({config, ...}: {
    options.allowUnfree = can.list.str "package names to ignore because unfree" {};
    options.config = can.attrs.anything "nixpkgs configuration (i.e. allowUnfreePredicate, etc.)" {};
    options.overlays = can.overlay "nixpkgs overlays" {};
    config = {
      config = lib.mkIf (config.allowUnfree != []) {
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.allowUnfree;
      };
      overlays = final: _: {
        canivete = final.writeShellScriptBin "canivete" (builtins.readFile ./utils.sh);
        fromYAML = can.pipe' [
          (file: "${final.yq}/bin/yq '.' ${file} > $out")
          (final.runCommand "from-yaml" {})
          lib.importJSON
        ];
        execBash = cmd: [(lib.getExe final.bash) "-c" cmd];
        wrapProgram = srcs: name: exe: args: overrides:
          final.symlinkJoin ({
              inherit name;
              buildInputs = [final.makeWrapper];
              paths = lib.toList srcs;
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
      };
    };
  });
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
