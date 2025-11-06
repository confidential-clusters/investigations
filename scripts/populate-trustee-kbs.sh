#!/bin/bash

set -euo pipefail
# set -x
source common.sh

if [[ "${#}" > 3 ]]; then
	echo "Usage: $0 <path-to-ssh-public-key>"
	echo "Optional: $0 <path-to-ssh-public-key> <SERVER_IP> <HOSTNAME>"
	exit 1
fi

KEY=$1
TRUSTEE_PORT=8080
IP=$2
if [[ ${IP} == "" ]]; then 
# Setup reference values, policies and secrets
until IP="$(./scripts/get-ip.sh trustee)" && [ -n "$IP" ] && curl "http://${IP}:${TRUSTEE_PORT}" >/dev/null 2>&1; do
	echo "Waiting for KBS to be available..."
	sleep 1
done
fi
until ssh core@$IP \
	-i "${KEY%.*}" \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	'sudo /usr/local/bin/populate_kbs.sh'; do
	echo "Waiting for KBS to be populated..."
	sleep 1
done

# Setup remote ignition config
HOSTNAME=$3
if [[ ${HOSTNAME} == "" ]]; then 
HOSTNAME=${IP}
fi
IGNITION=$(create_remote_ign_config $HOSTNAME)
scp -i "${KEY%.*}" \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	./${IGNITION} core@$IP:
# Setup remote web server to serve the ignition file
ssh core@$IP \
	-i "${KEY%.*}" \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	"sudo mv $IGNITION /srv/www && sudo systemctl restart nginx.service"
