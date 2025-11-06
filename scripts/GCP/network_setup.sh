#!/bin/bash

## create a subnet for the server and client VMs
SUBNET_NAME="demo-subnet-us-central1"
gcloud compute networks subnets create ${SUBNET_NAME} \
    --network=default \
    --region=us-central1 \
    --range=10.0.0.0/24
## allow ssh
RULE_NAME="allow-ssh"
NETWORK_NAME="default"
gcloud compute firewall-rules create ${RULE_NAME} \
    --network=${NETWORK_NAME} \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --description="Allow SSH from any IP"
## allow tcp on port 8080 for the trustee service
RULE_NAME="allow-tcp"
gcloud compute firewall-rules create ${RULE_NAME} \
    --network=${NETWORK_NAME} \
    --allow=tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --description="Allow TCP from any IP"