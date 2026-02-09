{lib, ...}: {
  imports = [./shared ./devenv];
  _module.args.can = import ./lib.nix lib;
}
