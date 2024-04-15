# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{
  nix,
  flake-parts-lib,
  inputs,
  ...
}: {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    options,
    pkgs,
    ...
  }:
    with nix; let
      tofu = config.canivete.opentofu;
      tofuOpts = options.canivete.opentofu;
    in {
      config.packages = mapAttrs (_: getAttr "configuration") tofu.workspaces;
      config.apps = mapAttrs (_: flip pipe [(getAttr "script") mkApp]) tofu.workspaces;
      options.canivete.opentofu = {
        workspaces = mkOption {
          default = {};
          description = mdDoc "Full OpenTofu configurations";
          type = attrsOf (submodule ({
            name,
            config,
            ...
          }: let
            workspace = config;
          in {
            options = {
              encryptedState.enable = mkEnabledOption "encrypted state (alpha prerelease)";
              encryptedState.passphrase =
                tofuOpts.sharedEncryptedStatePassphrase
                // {
                  default = tofu.sharedEncryptedStatePassphrase;
                };
              plugins = tofuOpts.sharedPlugins;
              modules = tofuOpts.sharedModules;
              package = mkOption {
                type = package;
                default =
                  if ! workspace.encryptedState.enable
                  then pkgs.opentofu
                  else
                    (
                      pkgs.opentofu.override {
                        buildGoModule = args:
                          pkgs.buildGoModule (args
                            // rec {
                              version = "1.7.0-alpha1";
                              src = pkgs.fetchFromGitHub {
                                owner = "opentofu";
                                repo = "opentofu";
                                rev = "v${version}";
                                hash = "sha256-tg3RsYWTvAL5sVMPHCwzTHe8EipdS3QdYmv6Jah1M1o=";
                              };
                              vendorHash = "sha256-N9csHGxUg8y+PshjPzEFOsdGF1cZch5UW3ISofQX9oE=";
                            });
                      }
                    );
                description = mdDoc "Final package with plugins";
              };
              finalPackage = mkOption {
                type = package;
                default = workspace.package.withPlugins (_: workspace.plugins);
                description = mdDoc "Final package with plugins";
              };
              configuration = mkOption {
                type = package;
                description = mdDoc "OpenTofu configuration file for workspace";
                default = inputs.terranix.lib.terranixConfiguration {
                  inherit pkgs;
                  modules = attrValues workspace.modules;
                };
              };
              script = mkOption {
                type = package;
                description = mdDoc "Script to run OpenTofu on the workspace configuration";
                default = pkgs.writeShellApplication {
                  name = "tofu-${name}";
                  runtimeInputs = with pkgs; [bash coreutils git vals workspace.finalPackage];
                  text = "${./utils.sh} ${./tofu.sh} --workspace ${name} --config ${workspace.configuration} -- \"$@\"";
                };
              };
            };
            config.plugins = tofu.sharedPlugins;
            config.modules = mkMerge [
              tofu.sharedModules
              # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
              {
                plugins.terraform.required_providers = pipe workspace.plugins [
                  (map (pkg: nameValuePair pkg.repo {inherit (pkg) source version;}))
                  listToAttrs
                ];
              }
              (mkIf workspace.encryptedState.enable {
                state.terraform.encryption = {
                  key_provider.pbkdf2.default.passphrase = mkDefault workspace.encryptedState.passphrase;
                  method.aes_gcm.default.keys = "\${ key_provider.pbkdf2.default }";
                  state.method = mkDefault "\${ method.aes_gcm.default }";
                  state.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
                  plan.method = mkDefault "\${ method.aes_gcm.default }";
                  plan.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
                };
              })
            ];
          }));
        };
        sharedEncryptedStatePassphrase = mkOption {
          type = str;
          default = "ref+sops://.canivete/sops/default.yaml#/opentofu_pw";
          description = mdDoc "Value or vals-like reference (i.e. ref+sops://...) to secret to decrypt state";
        };
        sharedModules = mkOption {
          type = attrsOf deferredModule;
          default = {};
          description = mdDoc "Terranix modules";
        };
        sharedPlugins = mkOption {
          default = [];
          description = mdDoc "Providers to pull";
          example = ["opentofu/google"];
          type = listOf (coercedTo str (
              source: let
                # TODO add all systems to allowing operating on different workstations
                inherit (pkgs.go) GOARCH GOOS;

                # Parse registry reference from path
                sourceParts = strings.splitString "/" source;
                owner = elemAt sourceParts 0;
                repo = elemAt sourceParts 1;
                path = "registry.opentofu.org/${source}";

                # Target latest system version
                file = inputs.opentofu-registry + "/providers/${substring 0 1 owner}/${source}.json";
                latest = head (importJSON file).versions;
                target = head (filter (e: e.arch == GOARCH && e.os == GOOS) latest.targets);
              in
                pkgs.stdenv.mkDerivation rec {
                  inherit (latest) version;
                  pname = "terraform-provider-${repo}";
                  src = pkgs.fetchurl {
                    url = target.download_url;
                    sha256 = target.shasum;
                  };
                  unpackPhase = "unzip -o $src";
                  nativeBuildInputs = [pkgs.unzip];
                  buildPhase = ":";
                  # The upstream terraform wrapper assumes the provider filename here
                  installPhase = ''
                    dir=$out/libexec/terraform-providers/${path}/${version}/${GOOS}_${GOARCH}
                    mkdir -p "$dir"
                    mv terraform-* "$dir/"
                  '';
                  passthru = {inherit repo source;};
                }
            )
            package);
        };
      };
    });
}
