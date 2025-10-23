#!/bin/bash

IGNITION_FILE="config.ign"
IGNITION_CONFIG="$(pwd)/trustee-on-GCP/${IGNITION_FILE}"


TRUSTEE_PORT=""

set -xe


force=false
while getopts "k:b:n:f p:s:d:t:i:" opt; do
  case $opt in
	k) key=$OPTARG ;;
	b) butane=$OPTARG ;;
	n) VM_NAME=$OPTARG ;;
	i) IMAGE=$OPTARG ;;
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

if [ ! -f "$key" ]; then
	echo "Error: The specified key file '$key' does not exist."
	exit 1
fi

KEY=$(cat "$key")

sed "s|<KEY>|$key|g" $butane | sed "s/<IP>/kbs/" > "${bufile}"

podman run --interactive --rm --security-opt label=disable \
	--volume "$(pwd)/trustee-on-GCP":/pwd -v "${bufile}":/config.bu:z --workdir /pwd quay.io/confidential-clusters/butane:clevis-pin-trustee \
	--pretty --strict /config.bu --output "/pwd/${IGNITION_FILE}" -d /pwd/rh-coreos

chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}



ZONE='us-central1-a'
MACHINE_TYPE='n2d-standard-2'

gcloud compute instances create ${VM_NAME}             \
	--image ${IMAGE}                                    \
    --metadata-from-file "user-data=${IGNITION_CONFIG}" \
    --confidential-compute-type "SEV_SNP"               \
    --machine-type "${MACHINE_TYPE}"                    \
    --maintenance-policy terminate                      \
    --zone "${ZONE}"                                    \
	--subnet "demo-subnet-us-central1"                   \
	--shielded-vtpm \
    --shielded-integrity-monitoring \
    --shielded-secure-boot
	
