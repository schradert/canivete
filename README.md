# Canivete

Nix framework for common development and infrastructure tooling like:

1. Managing infrastructure declaratively with OpenTofu through terranix
2. Administering kubernetes clusters with nixidy
3. Deploying Nix profiles (i.e. NixOS, nix-darwin, home-manager, etc.)
4. Package derivations with dream2nix
5. Container building and running with docker-compose through arion
6. Running packages as services locally using process-compose
7. Running development commands easily with just shorthand
8. Configure git hooks with pre-commit

## Requirements

1. [Nix](https://nixos.org/download/)
2. [Git](https://git-scm.com/), which can be installed easily through Nix

## Usage

1. Start a new project with `nix flake init --template github:schradert/canivete`
2. Open the project shell by entering project directory and running `nix develop`
3. See available commands by running `just`

## Notes

This repo supports building and deploy system configurations with `nixos`, `nix-darwin`, `nix-on-droid`, and `home-manager`.
Initial installation is slightly trickier, but this is accomplished in the following ways:

1. On Linux, we use `nixos-anywhere` to install `nixos` profiles with `disko` partitioning remotely
2. On Darwin and Linux without `nixos`, we assume `nix` is already installed
3. On Android, you must install [`nix-on-droid`](https://f-droid.org/packages/com.termux.nix)

In each case, SSH access is necessary and `nixos-anywhere` requires root access
