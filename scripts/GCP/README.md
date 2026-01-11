# Remote attestation with PCRs and AMD SEV-SNP on GCP using RHCOS

This guide provides step-by-step instructions for setting up remote attestation using PCRs and AMD SEV-SNP on Google Cloud Platform (GCP) with Red Hat CoreOS (RHCOS). It covers the deployment of a Trustee server and the creation of a custom RHCOS client image that communicates with the Trustee service to fetch encryption keys and decrypt the root image.


## Prerequisites

1. Copy the pull secret from [Red Hat OpenShift](https://console.redhat.com/openshift/create/local) to `~/.config/containers/auth.json` under `auths:quay.io:auth:<pull_secret>`
2. Install [gcloud](https://cloud.google.com/sdk/docs/install)
3. Configure a subnet on GCP for the server and client by running `./scripts/network_setup.sh`


## Deploy the Trustee Server (KBS)

1. To deploy the Trustee server, run:
```bash
./scripts/GCP/deploy-trustee.sh -k <SSH_KEY> -b ./configs/trustee.bu -i <IMAGE_NAME>
```
2. After the server is up, populate the KBS with the reference value and add the remote ignition file:
```bash
./scripts/populate-trustee-kbs.sh <SSH_KEY> <SERVER_IP> <HOSTNAME>
``` 
(The default hostname is `kbs`)


## Deploy the Client

1. Build a custom RHCOS image by running:
    ```bash
    cd coreos
    just os=scos base=quay.io/okd/scos-content:4.20.0-okd-scos.6-stream-coreos \
    platform=gcp build oci-archive osbuild
    ```

2. Upload the image to GCP by running:
    ```bash
    ./scripts/GCP/upload_image_gcp.sh <BUCKET_NAME> <IMAGE_NAME>
    ```

3. Deploy the client by running:
    ```bash
    ./scripts/GCP/deploy-vm.sh -k <SSH_KEY> -b ./configs/ak.bu -n <VM_NAME> -i <IMAGE_NAME> -h <HOSTNAME>
    ```
    This will create the VM, perform attestation, and decrypt the disk using clevis-pin.


## Information About KBS, KBS-Client, and Clevis-Pin

These are modified versions of [guest component](https://github.com/iroykaufman/guest-components/tree/TPM-as-additional-device) to support the TPM as an additional device.

The changes in the guest component are also included in [PR#1093](https://github.com/confidential-containers/guest-components/pull/1093).

## Attestation Policy

The policy only checks hardware for both SEV-SNP and TPM.

## Resource Policy

Verify that both devices are affirming and exist.


