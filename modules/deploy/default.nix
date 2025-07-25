flake @ {
  canivete,
  config,
  inputs,
  lib,
  withSystem,
  ...
}: let
  inherit (canivete) mkFlakeOption mkModuleOption mkNullableOption mkSystemOption;
  inherit (config.canivete.meta) people;
  inherit (config.canivete.deploy) nodes;
  inherit (config.canivete.deploy.canivete) flakes modules;
  inherit (lib) attrNames evalModules filterAttrsRecursive flip getExe mapAttrs mkDefault mkIf mkMerge mkOption optional optionalAttrs types;
  inherit (types) attrsOf bool deferredModule enum functionTo int listOf package path pathInStore raw str submodule;
  genericModule.options = {
    sshUser = mkNullableOption str {description = "User to connect with";};
    user = mkNullableOption str {description = "User to deploy to";};
    sudo = mkNullableOption str {description = "Sudo command";};
    interactiveSudo = mkNullableOption bool {description = "interactive sudo";};
    sshOpts = mkNullableOption (listOf str) {description = "SSH CLI args";};
    fastConnection = mkNullableOption bool {description = "fast connection";};
    autoRollback = mkNullableOption bool {description = "reactivation of previous profile on failure";};
    magicRollback = mkNullableOption bool {description = "magic rollback";};
    tempPath = mkNullableOption path {description = "Temporary file location for inotify watcher";};
    remoteBuild = mkNullableOption bool {description = "remote build on target system";};
    activationTimeout = mkNullableOption int {description = "Timeout for profile activation";};
    confirmTimeout = mkNullableOption int {description = "Timeout for profile activation confirmation";};
  };
  profileModule = profile @ {
    config,
    name,
    node,
    ...
  }: let
    inherit (config.canivete) activator builder configuration type;
    inherit (flakes.deploy.lib.${node.config.canivete.system}) activate;
    inherit (node.config.canivete) os system;
  in {
    imports = [genericModule];
    options.path = mkOption {
      type = pathInStore;
      default = activator configuration;
      description = "Path to activation script for given derivation";
    };
    options.profilePath = mkNullableOption path {description = "Profile installation path";};
    options.canivete = {
      type = mkOption {
        type = enum ["home-manager" "nixos" "darwin" "droid" "custom"];
        default =
          {
            nixos = "nixos";
            macos = "darwin";
            windows = "nixos";
            linux = "home-manager";
            android = "droid";
          }
          .${os};
        description = "Configuration module class (type of derivation)";
      };
      activator = mkOption {
        type = functionTo pathInStore;
        default =
          {
            inherit (activate) nixos darwin home-manager;
            droid = base: (activate.custom // {dryActivate = "$PROFILE/activate switch --dry-run";}) base.activationPackage "$PROFILE/activate switch";
            custom = base: activate.custom base.canivete.activationPackage (getExe base.canivete.activationPackage);
          }
          .${type};
        description = "How to build activation script for a derivation";
      };
      builder = mkOption {
        type = functionTo raw;
        default =
          {
            nixos = modules: flakes.nixos.lib.nixosSystem {modules = [modules];};
            darwin = modules: flakes.darwin.lib.darwinSystem {modules = [modules];};
            droid = modules:
              withSystem system ({pkgs, ...}:
                flakes.droid.lib.nixOnDroidConfiguration {
                  inherit pkgs;
                  modules = [modules];
                });
            home-manager = modules:
              withSystem system ({pkgs, ...}:
                flakes.home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;
                  modules = [modules];
                });
            custom = modules: evalModules {modules = [modules];};
          }
          .${type};
        description = "Convert modules to configurations";
      };
      configuration = mkOption {
        type = deferredModule;
        default = {};
        description = "Central module and configuration derivation for profile";
        apply = builder;
      };
      opentofu = mkOption {
        type = deferredModule;
        default = {};
        description = "Extra module to be injected in OpenTofu workspace for the node";
      };
    };
    config.user = mkDefault ({
        home-manager = name;
        nixos = "root";
      }
      .${type}
      or null);
    config.canivete.configuration.imports = [
      (withSystem system (perSystem: {_module.args = {inherit canivete flake node perSystem profile;};}))
      (modules.${type}
        or {
          options.canivete.activationPackage = mkOption {
            type = package;
            description = "Final package for custom profile";
          };
        })
      (optionalAttrs (type == "home-manager") {home.username = name;})
      # TODO when should I replace this with nixos-facter, etc.?
      (optionalAttrs (type != "custom") {nixpkgs.hostPlatform = system;})
    ];
    config.canivete.opentofu = {
      config,
      pkgs,
      ...
    }: let
      inherit (config.resource) null_resource;
      resource_name = "${type}_${node.name}_${name}";
      nixFlags =
        if type == "droid"
        then "--impure"
        else "";
    in {
      config = mkMerge [
        {
          data.external.${resource_name}.program = pkgs.execBash "nix eval .#canivete.deploy.nodes.${node.name}.profiles.${name}.path.drvPath | ${getExe pkgs.jq} '{drvPath:.}'";
          resource.null_resource.${resource_name} = {
            triggers.drvPath = "\${ data.external.${resource_name}.result.drvPath }";
            # deploy-rs currently runs all flake checks, which can fail when correctly deploying
            # TODO submit issue report to only run checks that deploy-rs creates
            provisioner.local-exec.command = "${getExe flakes.deploy.packages.${pkgs.system}.default} --skip-checks .#\"${node.name}\".\"${name}\" ${nixFlags}";
          };
        }
        # TODO support installation of nix system manager on every platform
        (mkIf (type == "nixos") {
          module."${resource_name}_install" = mkMerge [
            {
              source = "${flakes.anywhere}//terraform/install";
              target_host = node.config.hostname;
              flake = ".#${node.name}";
            }
            (mkIf (flakes.disko == null) {phases = ["kexec" "install" "reboot"];})
            (mkIf (null_resource ? sops) {depends_on = ["null_resource.sops"];})
          ];
          data.external.${resource_name}.depends_on = ["module.${resource_name}_install"];
        })
      ];
    };
  };
  nodeModule = node @ {
    config,
    name,
    ...
  }: {
    imports = [genericModule];
    options = {
      hostname = mkOption {
        type = str;
        default = name;
        description = "Server hostname";
      };
      profiles = mkOption {
        type = attrsOf (submodule {
          imports = [profileModule];
          _module.args = {inherit node;};
        });
        default = {};
        description = "All possible profiles to deploy on node";
      };
      profilesOrder = mkNullableOption (listOf (enum (attrNames config.profiles))) {description = "First profiles to deploy";};
      canivete.os = mkOption {
        type = enum ["nixos" "macos" "windows" "linux" "android"];
        default = "nixos";
        description = "Node operating system";
      };
      canivete.system = mkSystemOption {
        default =
          {
            macos = "aarch64-darwin";
            android = "aarch64-linux";
          }
          .${config.canivete.os}
          or "x86_64-linux";
      };
    };
  };
in {
  options.canivete.deploy = mkOption {
    type = submodule {
      imports = [genericModule];
      options.nodes = mkOption {
        type = attrsOf (submodule nodeModule);
        default = {};
        description = "Nodes to deploy profiles to";
      };
      options.canivete = {
        flakes = {
          deploy = mkFlakeOption "deploy-rs" {};
          nixos = mkFlakeOption "nixpkgs" {};
          darwin = mkFlakeOption "nix-darwin" {};
          droid = mkFlakeOption "nix-on-droid" {};
          home-manager = mkFlakeOption "home-manager" {};
          anywhere = mkFlakeOption "nixos-anywhere" {};
          disko = mkFlakeOption "disko" {};
        };
        modules = {
          home-manager = mkModuleOption {};
          nixos = mkModuleOption {};
          darwin = mkModuleOption {};
          droid = mkModuleOption {};
          system = mkModuleOption {};
          shared = mkModuleOption {};
        };
      };
      config.canivete.modules = let
        hostnameModule = {node, ...}: {networking.hostName = node.config.hostname;};
      in {
        home-manager.imports = [modules.shared];
        system = mkMerge [
          modules.shared
          # TODO can I do this for other systems too?
          # deadnix: skip
          (mkIf (flakes.home-manager != null) (systemConfiguration @ {pkgs, ...}: {
            home-manager.sharedModules = [
              {
                imports = [modules.home-manager];
                _module.args = {inherit systemConfiguration;};
              }
            ];
            home-manager.users = mapAttrs (username: _: {home = {inherit username;};}) people.users;
          }))
        ];
        nixos = mkMerge [
          {
            imports = [
              hostnameModule
              modules.system
            ];
            users.users = flip mapAttrs people.users (username: person: {
              isNormalUser = true;
              home = "/home/${username}";
              description = person.name;
              extraGroups = ["tty"] ++ (optional (username == people.me) "wheel");
            });
          }
          (mkIf (flakes.disko != null) flakes.disko.nixosModules.default)
          # TODO can I do this for other systems too?
          (mkIf (flakes.home-manager != null) ({
            node,
            perSystem,
            profile,
            utils,
            ...
          }: {
            imports = [flakes.home-manager.nixosModules.home-manager];
            home-manager.extraSpecialArgs = {inherit canivete flake node perSystem profile utils;};
            home-manager.sharedModules = [modules.home-manager];
          }))
        ];
        droid.imports = [modules.system flakes.home-manager.nixosModules.home-manager];
        # TODO figure out home-manager inside nix-darwin
        darwin.imports = [hostnameModule modules.system];
      };
    };
    default = {};
    description = "Deployment with deploy-rs and nixos-anywhere";
  };
  config = let
    inherit (lib) flatten flip getAttr getAttrFromPath mapAttrsToList pipe;
    typeNodes = type: let
      inherit (lib) attrValues filterAttrs getAttrFromPath head length mapAttrs pipe;
      typeProfiles = funcs: node: pipe node.profiles ([(filterAttrs (_: profile: profile.canivete.type == type)) attrValues] ++ funcs);
    in
      pipe nodes [
        # TODO what happens if there are multiple "system"-type configurations?!
        (filterAttrs (_: typeProfiles [length (l: l == 1)]))
        (mapAttrs (_: typeProfiles [head (getAttrFromPath ["canivete" "configuration"])]))
      ];
    nixosConfigurations = typeNodes "nixos";
    darwinConfigurations = typeNodes "darwin";
    nixOnDroidConfigurations = typeNodes "droid";
    homeManagerConfigurations = typeNodes "home-manager";
  in
    mkIf (nodes != {}) {
      flake = mkMerge [
        {deploy = filterAttrsRecursive (name: value: name != "canivete" && value != null) config.canivete.deploy;}
        (mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
        (mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
        (mkIf (nixOnDroidConfigurations != {}) {inherit nixOnDroidConfigurations;})
        (mkIf (homeManagerConfigurations != {}) {inherit homeManagerConfigurations;})
      ];
      perSystem = {system, ...}: {
        checks = flakes.deploy.lib.${system}.deployChecks inputs.self.deploy;
        canivete.opentofu.workspaces.deploy = {
          modules.imports = pipe nodes [
            (mapAttrsToList (_:
              flip pipe [
                (getAttr "profiles")
                (mapAttrsToList (_: getAttrFromPath ["canivete" "opentofu"]))
              ]))
            flatten
          ];
          plugins = ["hashicorp/null" "hashicorp/external"];
        };
      };
    };
}
