#! /usr/bin/env bash

cluster=
config=
while [[ $# -gt 0 ]]; do
	case $1 in
	--cluster)
		cluster=$2
		shift
		;;
	--config)
		config=$2
		shift
		;;
	--)
		shift
		break
		;;
	*) logfx exit_status=FAILURE level=ERROR <<<"Not a valid option: $1" ;;
	esac
	shift
done
[[ -z ${config-} ]] && logfx exit_status=FAILURE level=ERROR <<<"Must specify a --config file"
[[ -z ${cluster-} ]] && logfx exit_status=FAILURE level=ERROR <<<"Must specify a --cluster name"

# shellcheck disable=SC2154
run_dir="$CANIVETE_GIT_DIR/opentofu/$cluster"
dec_tfstate="$run_dir/terraform.tfstate.dec"
enc_file="$run_dir/config.enc.yaml"
dec_file="$run_dir/config.yaml"
mkdir -p "$run_dir"
cp -L "$config" "$enc_file"
chmod 644 "$enc_file"
tofu "-chdir=$run_dir" state pull >"$dec_tfstate"
vals eval -s -f "$enc_file" | yq "." --yaml-output >"$dec_file"
rm -f "$dec_tfstate"

enc_kube="$run_dir/kubeconfig.enc"
dec_kube="$run_dir/kubeconfig"
sops --decrypt --input-type yaml --output-type binary --output "$dec_kube" "$enc_kube" &>/dev/null

args=(--kubeconfig "$dec_kube" "$@")
if contains apply args; then
	args+=(--filename "$dec_file")
fi
logfx <<<"Running 'kubectl ${args[*]}'"
kubectl "${args[@]}"
