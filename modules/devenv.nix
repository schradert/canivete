{
  can,
  inputs,
  lib,
  ...
}: {
  imports = [(inputs.devenv.flakeModule or {})];
  config = lib.mkIf (inputs ? devenv) {
    perSystem = {lib, ...}: {
      imports = [(lib.mkAliasOptionModule ["canivete" "devenv"] ["devenv"])];
      devenv.modules = [
        ({
          config,
          pkgs,
          ...
        }: {
          options.languages = {
            toml.enable = can.enable "TOML language tools" {};
            yaml.enable = can.enable "YAML language tools" {};
          };
          options.editors = {
            zed.enable = can.enable "Zed editor integration" {};
            zed.settings = can.json.option pkgs ".zed/settings.json" {};
            helix.enable = can.enable "Zed editor integration" {};
            helix.languages = can.toml.option pkgs ".helix/languages.toml" {};
          };
          config = lib.mkMerge [
            (lib.mkIf config.editors.zed.enable {files.".zed/settings.json".json = config.editors.zed.settings;})
            (lib.mkIf config.editors.helix.enable {files.".helix/languages.toml".toml = config.editors.helix.languages;})
          ];
        })
        ({pkgs, ...}: {
          _module.args = {inherit can;};
          git-hooks.default_stages = ["pre-commit" "pre-push" "manual"];
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
              no-commit-to-branch.settings.branch = ["main" "develop" "trunk"];
              trim-trailing-whitespace.enable = true;

              # third-party
              commitizen.enable = true;
              gitleaks.enable = true;
              gitleaks.entry = "${pkgs.gitleaks}/bin/gitleaks protect --redact";
              lychee = {config, ...}: {
                options.toml = can.toml.option pkgs "Contents of lychee.toml" {};
                config.enable = true;
                config.settings.configPath = toString (can.toml.generate pkgs "lychee.toml" config.toml);
              };
              tagref.enable = true;
              typos.enable = true;
            }
          ];
        })
        ({pkgs, ...}: {
          languages.nix.enable = true;
          packages = [pkgs.nixd];
          editors.zed.settings = {
            lsp.nixd = {};
            languages.Nix = {
              language_servers = ["nixd"];
              formatter = {
                external = {
                  command = "alejandra";
                  arguments = [];
                };
              };
              format_on_save = "on";
            };
          };
          editors.helix.languages.language = [
            {
              name = "nix";
              formatter.command = "alejandra";
              language-servers = ["nixd"];
              auto-format = true;
            }
          ];
          git-hooks.hooks = {
            alejandra.enable = true;
            deadnix.enable = true;
            statix = {config, ...}: {
              options.toml = can.toml.option pkgs "Contents of statix.toml" {};
              config.enable = true;
              config.settings.config = toString (can.toml.generate pkgs "statix.toml" config.toml);
              config.toml.disabled = ["repeated_keys"];
            };
          };
        })
        ({pkgs, ...}: {
          treefmt.enable = true;
          treefmt.config.programs.dprint = {
            enable = true;
            settings.plugins = pkgs.dprint-plugins.getPluginList (ps: [ps.dprint-plugin-markdown]);
          };
          git-hooks.hooks.treefmt.enable = true;
          editors.zed.settings = {
            lsp.marksman = {};
            languages.Markdown = {
              language_servers = ["marksman"];
              formatter = {
                external = {
                  command = "dprint";
                  arguments = ["fmt" "--stdin" "md"];
                };
              };
              format_on_save = "on";
            };
          };
          editors.helix.languages.language = [
            {
              name = "markdown";
              formatter.command = "dprint";
              formatter.args = ["fmt" "--stdin" "md"];
              language-servers = ["marksman"];
              auto-format = true;
            }
          ];
          git-hooks.hooks = {
            markdownlint.enable = true;
            markdownlint.settings.configuration.MD013.line_length = -1;
            mdsh.enable = true;
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.rust.enable {
            languages.toml.enable = true;
            git-hooks.hooks = {
              clippy.enable = true;
              rustfmt.enable = true;
            };
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.javascript.enable {
            git-hooks.hooks.biome.enable = true;
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.go.enable {
            git-hooks.hooks.golangci-lint.enable = true;
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.shell.enable {
            git-hooks.hooks = {
              shellcheck.enable = true;
              shfmt.enable = true;
              shfmt.raw.args = ["--indent" (toString 4)];
            };
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.python.enable {
            languages.python = {
              uv.enable = true;
              uv.sync.enable = true;
              venv.enable = true;
            };
            languages.toml.enable = true;
            processes.ty.exec = "ty check --watch";
            editors.zed.settings = {
              lsp.ty.initialization_options = {
                inlayHints.callArgumentNames = false;
                experimental.rename = true;
                experimental.autoImport = true;
              };
              languages.Python = {
                language_servers = ["ty" "!basedpyright" "..."];
                formatter = {
                  external = {
                    command = "ruff";
                    arguments = ["format" "-"];
                  };
                };
                format_on_save = "on";
              };
            };
            editors.helix.languages = {
              language-server.ty = {
                command = "ty";
                args = ["server"];
                config = {
                  # TODO should this be configured in pyproject.toml?
                  "inlayHints.callArgumentNames" = false;
                  "experimental.rename" = true;
                  "experimental.autoImport" = true;
                };
              };
              languages = [
                {
                  name = "python";
                  formatter.command = "ruff";
                  formatter.args = ["format" "-"];
                  language-servers = ["ty"];
                  auto-format = true;
                }
              ];
            };
            git-hooks.hooks = {
              # pre-commit builtin hooks
              check-builtin-literals.enable = true;
              check-docstring-first.enable = true;
              check-python.enable = true;
              name-tests-test.enable = true;
              python-debug-statements.enable = true;

              ruff.enable = true;
              ruff-format.enable = true;
              ty.enable = true;
              ty.entry = "${config.devenv.state}/venv/bin/ty check";
              ty.types = ["python"];
            };
          };
        })
        ({config, ...}: {
          config = lib.mkIf config.languages.toml.enable {
            editors.zed.settings = {
              lsp.taplo = {};
              languages.TOML = {
                language_servers = ["taplo"];
                formatter = {
                  external = {
                    command = "taplo";
                    arguments = ["format" "-"];
                  };
                };
                format_on_save = "on";
              };
            };
            editors.helix.languages.language = [
              {
                name = "toml";
                roots = ["."];
                formatter.command = "taplo";
                formatter.args = ["format" "-"];
                language-servers = ["taplo"];
                auto-format = true;
              }
            ];
            git-hooks.hooks.taplo.enable = true;
          };
        })
        ({
          config,
          pkgs,
          ...
        }: {
          config = lib.mkIf config.languages.yaml.enable {
            treefmt.enable = true;
            treefmt.config.programs.dprint = {
              enable = true;
              settings.plugins = pkgs.dprint-plugins.getPluginList (ps: [ps.g-plane-pretty_yaml]);
            };
            git-hooks.hooks.treefmt.enable = true;
            git-hooks.hooks.yamllint.enable = true;
            editors.zed.settings = {
              lsp.yaml-language-server = {};
              languages.YAML = {
                language_servers = ["yaml-language-server"];
                formatter = {
                  external = {
                    command = "dprint";
                    arguments = ["fmt" "--stdin" "yaml"];
                  };
                };
                format_on_save = "on";
              };
            };
            editors.helix.languages.language = [
              {
                name = "yaml";
                formatter.command = "dprint";
                formatter.args = ["fmt" "--stdin" "yaml"];
                language-servers = ["yaml-language-server"];
                auto-format = true;
              }
            ];
          };
        })
        ({
          config,
          pkgs,
          ...
        }: {
          options.languages.sql = {
            enable = can.enable "SQL language tooling" {};
            lsp.package = can.package "LSP language server" {
              default = pkgs.rustPlatform.buildRustPackage rec {
                pname = "sqlfluff-lsp";
                version = "0.3.1";
                src = pkgs.fetchFromGitHub {
                  owner = "VasanthakumarV";
                  repo = "sqlfluff-lsp";
                  rev = "v${version}";
                  hash = "sha256-scZwIKa9NcID0x/Nx1Nm9phZSxj2f5j1Yv9pOc4dc0M=";
                };
                cargoHash = "sha256-+hZsjYYXqmG9xIeO+64KOJziRw/GhiO1UY+If4pjHfE=";
                buildInputs = [config.treefmt.config.programs.sqlfluff.package];
                nativeCheckInputs = [config.treefmt.config.programs.sqlfluff.package];
                meta = {
                  description = "Language Server for the SQL linting & formatting tool, SQLFluff.";
                  homepage = "https://github.com/${src.owner}/${src.repo}";
                  license = lib.licenses.mit;
                  mainProgram = "sqlfluff-lsp";
                };
              };
            };
          };
          config = lib.mkIf config.languages.sql.enable {
            treefmt.enable = true;
            treefmt.config.programs = {
              sqlfluff.enable = true;
              sqlfluff.dialect = "snowflake";
              sqlfluff-lint.enable = true;
            };
            packages = [config.languages.sql.lsp.package];
            editors.zed.settings = {
              lsp.sqlfluff-lsp = {};
              languages.SQL = {
                language_servers = ["sqlfluff-lsp"];
                formatter = {
                  external = {
                    command = "sqlfluff";
                    arguments = ["format" "-"];
                  };
                };
                format_on_save = "on";
              };
            };
            editors.helix.languages = {
              language-server.sqlfluff-lsp = {
                command = "sqlfluff-lsp";
                args = ["serve"];
              };
              language = [
                {
                  name = "sql";
                  formatter.command = "sqlfluff";
                  formatter.args = ["format" "-"];
                  language-servers = ["sqlfluff-lsp"];
                  auto-format = true;
                }
              ];
            };
          };
        })
      ];
    };
  };
}
