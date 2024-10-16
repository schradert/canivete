# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{
  nix,
  inputs,
  ...
}: {
  perSystem = perSystem @ {
    config,
    options,
    pkgs,
    system,
    ...
  }:
    with nix; let
      tofu = config.canivete.opentofu;
      tofuOpts = options.canivete.opentofu;
    in {
      config.packages.opentofu = pkgs.writeShellApplication {
        name = "opentofu";
        text = ''
          git_dir="$(${getExe pkgs.git} rev-parse --show-toplevel)"
          run_dir="$git_dir/.canivete/opentofu/$1"
          dec_file="$run_dir/config.tf.json"
          mkdir -p "$run_dir"
          trap 'rm -rf "$run_dir/.terraform" "$run_dir/.terraform.lock.hcl" "$dec_file"' EXIT
          nix build ".#canivete.${system}.opentofu.workspaces.$1.configuration" --no-link --print-out-paths | \
            xargs cat | \
            ${getExe pkgs.vals} eval -s -f - | \
            ${getExe pkgs.yq} "." >"$dec_file"
          nix run ".#canivete.${system}.opentofu.workspaces.$1.finalPackage" -- -chdir="$run_dir" init -upgrade
          nix run ".#canivete.${system}.opentofu.workspaces.$1.finalPackage" -- -chdir="$run_dir" "''${@:2}"
        '';
      };
      options.canivete.opentofu = {
        workspaces = mkOption {
          default = {};
          description = "Full OpenTofu configurations";
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
                default = pkgs.opentofu;
                description = "Final package with plugins";
              };
              finalPackage = mkOption {
                type = package;
                default = workspace.package.withPlugins (_: workspace.plugins);
                description = "Final package with plugins";
              };
              composition = mkOption {
                type = raw;
                description = "Evaluated terranix composition";
                default = inputs.terranix.lib.terranixConfigurationAst {
                  inherit pkgs;
                  extraArgs = {inherit nix;};
                  modules = attrValues workspace.modules;
                };
              };
              configuration = mkOption {
                type = package;
                description = "OpenTofu configuration file for workspace";
                default = (pkgs.formats.json {}).generate "config.tf.json" workspace.composition.config;
              };
            };
            config.plugins = tofu.sharedPlugins;
            config.modules = mkMerge [
              tofu.sharedModules
              # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
              {
                plugins.terraform.required_providers = pipe workspace.plugins [
                  # TODO why do I need to be explicit here as well?!
                  (concat tofu.sharedPlugins)
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
          default = vals.sops "default.yaml#/opentofu_pw";
          description = "Value or vals-like reference (i.e. ref+sops://... or with nix.vals.sops) to secret to decrypt state";
        };
        sharedModules = mkOption {
          type = attrsOf deferredModule;
          default = {};
          description = "Terranix modules";
        };
        sharedPlugins = mkOption {
          default = [];
          description = "Providers to pull";
          example = ["opentofu/google/1.0.0" "opentofu/random"];
          type = listOf (coercedTo str (
              provider: let
                inherit (pkgs.go) GOARCH GOOS;

                # Parse source (e.g. "owner/repo[/versionTry]")
                providerParts = strings.splitString "/" provider;
                owner = elemAt providerParts 0;
                repo = elemAt providerParts 1;
                source = "${owner}/${repo}";

                # Target system version (latest by default)
                version = let
                  file = inputs.opentofu-registry + "/providers/${substring 0 1 owner}/${source}.json";
                  inherit (importJSON file) versions;
                  hasSpecificVersion = (length providerParts) == 3;
                  specificVersion = head (filter (v: v.version == elemAt providerParts 2) versions);
                  latestVersion = head versions;
                in ifElse hasSpecificVersion specificVersion latestVersion;
                target = head (filter (t: t.arch == GOARCH && t.os == GOOS) version.targets);
              in
                pkgs.stdenv.mkDerivation {
                  inherit (version) version;
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
                    dir=$out/libexec/terraform-providers/registry.opentofu.org/${source}/${version.version}/${GOOS}_${GOARCH}
                    mkdir -p "$dir"
                    mv terraform-* "$dir/"
                  '';
                  passthru = {inherit repo source;};
                }
            )
            package);
        };
      };
    };
}
