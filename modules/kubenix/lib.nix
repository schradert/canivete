{
  canivete,
  lib,
  ...
}: let
  inherit (lib) mkOption types pipe getAttrFromPath attrValues getAttr;
  inherit (types) enum port listOf submodule str path bool strMatching;
in {
  _module.args.canivete.kubenix = {
    mkPullPolicyOption = _:
      mkOption {
        type = enum ["Always" "Never" "IfNotExist"];
        default = "Always";
        example = "IfNotExist";
        description = "When to pull artifact";
      };
    mkPortOption = default:
      mkOption {
        type = port;
        inherit default;
        example = 8080;
        description = "Port to communicate over";
      };
    mkNameValuePairsOption = type: doc:
      mkOption {
        type = listOf (submodule {
          options.name = mkOption {type = str;};
          options.value = mkOption {inherit type;};
        });
        default = [];
        example = [
          {
            name = "MY_ENV_VAR";
            value = "test";
          }
        ];
        description = doc;
      };
    # TODO why wasn't having this be a recursive attrset working
    mkEnvOption = _: canivete.kubenix.mkNameValuePairsOption str "Environment variables";
    mkEnvSecretsOption = secrets:
      mkOption {
        type = listOf (submodule {
          options.name = mkOption {
            type = pipe secrets [
              attrValues
              (map (getAttrFromPath ["metadata" "name"]))
              enum
            ];
          };
        });
        default = [];
        description = "Create environment variables from these secrets";
      };
    mkVolumesOption = _:
      mkOption {
        type = listOf (submodule {
          options.name = mkOption {type = str;};
          options.secret.secretName = mkOption {type = str;};
        });
        default = [];
        description = "Secrets to mount as volumes in the Pod";
      };
    mkVolumeMountsOption = volumes:
      mkOption {
        type = listOf (submodule {
          options.name = mkOption {
            type = enum (map (getAttr "name") volumes);
            description = "Which volume to mount";
          };
          options.mountPath = mkOption {
            type = path;
            example = "/path/to/mount/files";
            description = "Where the volume files will live in the Pod";
          };
          options.readOnly = mkOption {
            type = bool;
            default = false;
            example = true;
            description = "Whether the volume mount should be read only";
          };
        });
        default = [];
        description = "Secrets to mount as volumes in the Pod";
      };
    mkPostgresOption = args:
      mkOption ({
          type = strMatching "^([a-zA-Z]|_[a-zA-Z0-9])[a-zA-Z0-9_]{0,62}$";
          example = "_Special";
          description = "Postgres variable";
        }
        // args);
  };
}
