# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
flake @ {inputs, ...}: {
  # TODO try out the flake module!
  perSystem = perSystem @ {
    canivete,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (canivete) vals ifElse mkEnabledOption;
    inherit (config.canivete) opentofu;
    inherit (lib) mkOption mkEnableOption mkMerge nameValuePair mkIf listToAttrs types mkDefault strings readFile;
    inherit (types) attrsOf package str deferredModule submodule;
  in {
    options.canivete.opentofu = {
      enable = mkEnableOption "OpenTofu workspaces" // {default = inputs ? terranix;};
      script = mkOption {
        type = package;
        default = pkgs.writeShellApplication {
          name = "opentofu";
          runtimeInputs = with pkgs; [git gum yq] ++ [pkgs.vals config.canivete.scripts.utils];
          text = readFile ./opentofu.sh;
        };
      };
      sharedModules = mkOption {
        type = deferredModule;
        default = {};
        description = "";
      };
      workspaces = mkOption {
        default = {};
        description = "OpenTofu workspaces!";
        type = attrsOf (submodule (workspace @ {
          config,
          # deadnix: skip
          name,
          ...
        }: {
          options = {
            encryptedState.enable = mkEnabledOption "encrypted state (alpha prerelease)";
            encryptedState.passphrase = mkOption {
              type = str;
              default = vals.sops.default "opentofu_pw";
              description = "Value or vals-like reference (i.e. ref+sops://... or with nix.vals.sops) to secret to decrypt state";
            };
            plugins = mkOption {
              default = [];
              description = "Providers to pull";
              example = ["hashicorp/google/1.0.0" "hashicorp/random"];
              type = let
                inherit (lib) elemAt substring importJSON length head filter;
                inherit (types) listOf coercedTo;
                inherit (pkgs.go) GOARCH GOOS;
                strToPackage = provider: let
                  # Parse source (e.g. "owner/repo[/versionTry]")
                  providerParts = strings.splitString "/" provider;
                  owner = elemAt providerParts 0;
                  repo = elemAt providerParts 1;
                  source = "${owner}/${repo}";

                  # Target system version (latest by default)
                  version = let
                    upstreamOwner =
                      if owner == "hashicorp"
                      then "opentofu"
                      else owner;
                    file = inputs.opentofu-registry + "/providers/${substring 0 1 upstreamOwner}/${upstreamOwner}/${repo}.json";
                    inherit (importJSON file) versions;
                    hasSpecificVersion = (length providerParts) == 3;
                    specificVersion = head (filter (v: v.version == elemAt providerParts 2) versions);
                    latestVersion = head versions;
                  in
                    ifElse hasSpecificVersion specificVersion latestVersion;
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
                  };
              in
                listOf (coercedTo str strToPackage package);
            };
            package = mkOption {
              type = package;
              default = pkgs.opentofu.withPlugins (_: config.plugins);
              description = "Final package with plugins";
            };
            json = mkOption {
              type = package;
              default = (pkgs.formats.json {}).generate "config.tf.json" config.modules.config;
              description = "OpenTofu configuration file for workspace";
            };
            modules = mkOption {
              type = deferredModule;
              default = {};
              description = "Workspace modules to configuration";
              apply = modules:
                inputs.terranix.lib.terranixConfigurationAst {
                  inherit pkgs;
                  extraArgs = {inherit workspace canivete flake perSystem;};
                  modules = [opentofu.sharedModules modules];
                };
            };
          };
        }));
      };
    };
    config = mkIf opentofu.enable {
      canivete.devenv.shells.default.scripts.tofu.exec = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").opentofu.script \"\${NIX_OPTIONS[@]}\" -- \"$@\"";
      canivete.opentofu.sharedModules = {workspace, ...}: let
        inherit (workspace.config) encryptedState plugins;
      in {
        variable.GIT_DIR.type = "string";
        terraform = mkMerge [
          {
            # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
            required_providers = let
              pluginToProvider = pkg: nameValuePair pkg.repo {inherit (pkg) source version;};
            in
              listToAttrs (map pluginToProvider plugins);
          }
          (mkIf encryptedState.enable {
            encryption = {
              key_provider.pbkdf2.default.passphrase = mkDefault encryptedState.passphrase;
              method.aes_gcm.default.keys = "\${ key_provider.pbkdf2.default }";
              state.method = mkDefault "\${ method.aes_gcm.default }";
              state.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
              plan.method = mkDefault "\${ method.aes_gcm.default }";
              plan.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
            };
          })
        ];
      };
    };
  };
}
