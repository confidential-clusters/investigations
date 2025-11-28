#!/bin/bash

set -euo pipefail
# set -x

image="$HOME/projects/bootc/bootc/examples/test-filesystem-fcos-uki-cocl.img"
dest="$HOME/projects/confidential-clusters/investigations/fcos-cvm-qemu.x86_64.img"
if [[ -f $image ]]; then
    mv "$image" "$dest"
fi

cp "$HOME/projects/bootc/bootc/examples/bootc-bls/OVMF_VARS_CUSTOM.qcow2" "$HOME/projects/confidential-clusters/investigations/"

KEY=$HOME/.ssh/keys/local.pub
CUSTOM_IMAGE="$(pwd)/fcos-cvm-qemu.x86_64.img"

scripts/install_vm.sh \
	-n vm \
	-b configs/luks.bu \
	-k "$(cat "$KEY")" \
	-f \
	-i "${CUSTOM_IMAGE}" \
	-m 5192
