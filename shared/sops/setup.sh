#!/usr/bin/env bash

usage="$0 [-n|--name NAME (default: SOPS)] [-h|--help]"

NAME="${CANIVETE_SOPS_SSH_KEY_NAME:-SOPS}"
AGE_KEY_FILE="${CANIVETE_SOPS_AGE_KEY_FILE-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --name)
        NAME="$2"
        shift
        ;;
    -f | --age-key-file)
        AGE_KEY_FILE="$2"
        shift
        ;;
    -h | --help)
        gum log "$usage"
        exit
        ;;
    *)
        break
        ;;
    esac
    shift
done
if [[ -z $NAME ]]; then
    gum log --level error "Name '$NAME' is not valid for SSH key"
    exit 1
fi
if [[ -z $AGE_KEY_FILE ]]; then
    gum log --level error "Location '$AGE_KEY_FILE' is not valid for storing age private key"
    exit 1
fi

ssh_key_file="$HOME/.ssh/$NAME"

mkdir -p "$(dirname "$AGE_KEY_FILE")"

gum log "Generating SSH key..."
ssh-keygen -t ed25519 -P "" -f "$ssh_key_file" &>/dev/null

gum log "Saving private age key"
ssh-to-age -private-key -i "$ssh_key_file" >"$AGE_KEY_FILE" 2>/dev/null

gum log "Public age key is $(age-keygen -y "$AGE_KEY_FILE")"
