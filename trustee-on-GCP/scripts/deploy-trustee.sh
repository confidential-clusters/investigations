#!/bin/bash

IGNITION_FILE="config.ign"
IGNITION_CONFIG="$(pwd)/${IGNITION_FILE}"


TRUSTEE_PORT=""

set -xe


VM_NAME="kbs"

while getopts "k:b:n:f p:s:d:t:i:" opt; do
  case $opt in
	k) key=$OPTARG ;;
	b) butane=$OPTARG ;;
	n) VM_NAME=$OPTARG ;;
	\?) echo "Invalid option"; exit 1 ;;
  esac
done


if [ -z "${key}" ]; then
	echo "Please, specify the public ssh key"
	exit 1
fi
if [ -z "${butane}" ]; then
	echo "Please, specify the butane configuration file"
	exit 1
fi



bufile=$(mktemp)

KEY=$(cat "$key")

sed "s|<KEY>|$KEY|g" "$butane" >"${bufile}"

podman run --interactive --rm --security-opt label=disable \
	--volume "$(pwd)":/pwd -v "${bufile}":/config.bu:z --workdir /pwd quay.io/coreos/butane:release \
	--pretty --strict /config.bu --output "/pwd/${IGNITION_FILE}" -d /pwd/trustee

chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}



ZONE='us-central1-a'
MACHINE_TYPE='n2d-standard-2'

gcloud compute instances create ${VM_NAME}             \
	--image-project "rhcos-cloud"    \
    --image "rhcos-9-6-20250911-0-gcp-x86-64"   \
    --metadata-from-file "user-data=${IGNITION_CONFIG}" \
    --confidential-compute-type "SEV_SNP"               \
    --machine-type "${MACHINE_TYPE}"                    \
    --maintenance-policy terminate                      \
    --zone "${ZONE}"                                    \
	--subnet "demo-subnet-us-central1"                   \
	--shielded-vtpm \
    --shielded-integrity-monitoring \
    --shielded-secure-boot  \

