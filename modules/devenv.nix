{inputs, ...}: {
  imports = [(inputs.devenv.flakeModule or {})];
  perSystem = {lib, ...}: {
    imports = lib.optional (inputs ? devenv) (lib.mkAliasOptionModule ["canivete" "devenv"] ["devenv"]);
    devenv.modules = [
      ({
        config,
        pkgs,
        ...
      }: let
        inherit (config) languages;
        toml = pkgs.formats.toml {};
      in {
        git-hooks.default_stages = lib.mkDefault ["pre-push" "manual"];
        git-hooks.excludes = [".canivete"];
        git-hooks.hooks = lib.mkMerge [
          {
            # pre-commit builtin hooks
            check-added-large-files.enable = true;
            check-case-conflicts.enable = true;
            check-executables-have-shebangs.enable = true;
            check-merge-conflicts.enable = true;
            check-symlinks.enable = true;
            check-vcs-permalinks.enable = true;
            end-of-file-fixer.enable = true;
            fix-byte-order-marker.enable = true;
            forbid-new-submodules.enable = true;
            mixed-line-endings.enable = true;
            no-commit-to-branch.enable = true;
            no-commit-to-branch.settings.branch = ["trunk"];
            trim-trailing-whitespace.enable = true;

            # third-party
            commitizen.enable = true;
            gitleaks.enable = true;
            gitleaks.entry = "${pkgs.gitleaks}/bin/gitleaks protect --redact";
            lychee = {config, ...}: {
              options.toml = lib.mkOption {
                inherit (toml) type;
                default = {};
                description = "Contents of lychee.toml";
              };
              config.enable = true;
              config.settings.configPath = toString (toml.generate "lychee.toml" config.toml);
            };
            markdownlint.enable = true;
            markdownlint.settings.configuration.MD013.line_length = -1;
            mdsh.enable = true;
            tagref.enable = true;
            typos.enable = true;

            # nix
            alejandra.enable = true;
            deadnix.enable = true;
            statix = {config, ...}: {
              options.toml = lib.mkOption {
                inherit (toml) type;
                default = {};
                description = "Contents of statix.toml";
              };
              config.enable = true;
              config.toml.disabled = lib.mkDefault ["unquoted_uri" "repeated_keys"];
              config.raw.args = ["--config" (toml.generate "statix.toml" config.toml)];
            };
          }
          (lib.mkIf languages.python.enable {
            # pre-commit builtin hooks
            check-builtin-literals.enable = true;
            check-docstring-first.enable = true;
            check-python.enable = true;
            name-tests-test.enable = true;
            python-debug-statements.enable = true;

            flake8.enable = true;
            mypy.enable = true;
            ruff.enable = true;
            taplo.enable = true;
          })
          (lib.mkIf languages.rust.enable {
            clippy.enable = true;
            rustfmt.enable = true;
            taplo.enable = true;
          })
          (lib.mkIf languages.shell.enable {
            shellcheck.enable = true;
            shfmt.enable = true;
            shfmt.raw.args = ["--indent" (toString 4)];
          })
          (lib.mkIf languages.javascript.enable {
            biome.enable = true;
          })
          (lib.mkIf languages.go.enable {
            golangci-lint.enable = true;
          })
        ];
      })
    ];
  };
}
