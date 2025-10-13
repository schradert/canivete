{
  canivete,
  lib,
  ...
}: let
  inherit (canivete) mkNullableOption;
  inherit (lib.types) bool int listOf path str;
in {
  options = {
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
}
