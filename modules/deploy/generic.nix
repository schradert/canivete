{can, ...}: {
  options = {
    sshUser = can.opt.str "user to connect with" {};
    user = can.opt.str "user to deploy to" {};
    sudo = can.opt.str "sudo command" {};
    interactiveSudo = can.opt.bool "interactive sudo" {};
    sshOpts = can.opt.list.str "ssh cli args" {};
    fastConnection = can.opt.bool "fast connection" {};
    autoRollback = can.opt.bool "reactivation of previous profile on failure" {};
    magicRollback = can.opt.bool "magic rollback" {};
    tempPath = can.opt.path "temporary file location for inotify watcher" {};
    remoteBuild = can.opt.bool "remote build on target system" {};
    activationTimeout = can.opt.int "timeout for profile activation" {};
    confirmTimeout = can.opt.int "timeout for profile activation confirmation" {};
  };
}
