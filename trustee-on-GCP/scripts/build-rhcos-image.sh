#!/bin/bash



IMG_NAME=$1
ociarchive=${IMG_NAME}.tar

set -xe

sudo setenforce 0

TMPDIR=$(mktemp -d)
git clone --depth 1 https://github.com/coreos/custom-coreos-disk-images ${TMPDIR}

# Build the container image
sudo podman build -t ${IMG_NAME} -f rh-coreos/Containerfile  rh-coreos

sudo skopeo copy containers-storage:localhost/${IMG_NAME}:latest oci-archive:${ociarchive}
sudo -E ${TMPDIR}/custom-coreos-disk-images.sh --platform gcp \
	--ociarchive ${ociarchive} \
	--osname rhcos
rm -rf "$TMPDIR"
