# Remote attestation with PCRs and AMD SEV-SNP on GCP using RHCOS

This guide provides step-by-step instructions for setting up remote attestation using PCRs and AMD SEV-SNP on Google Cloud Platform (GCP) with Red Hat CoreOS (RHCOS). It covers the deployment of a Trustee server and the creation of a custom RHCOS client image that communicates with the Trustee service to fetch encryption keys and decrypt the root image.


## Prerequisites

1. Copy the pull secret from [Red Hat OpenShift](https://console.redhat.com/openshift/create/local) to `~/.config/containers/auth.json` under `auths:quay.io:auth:<pull_secret>`
2. Install [gcloud](https://cloud.google.com/sdk/docs/install)
3. Configure a subnet on GCP for the server and client by running `./scripts/network_setup.sh`


## Deploy the Trustee Server (KBS)

1. To deploy the Trustee server, run:
```bash
./scripts/GCP/deploy-trustee.sh -k <SSH_KEY> -b ./configs/trustee-gcp.bu -i <IMAGE_NAME>
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
    just clevis_pin_trustee_image=quay.io/rkaufman/clevis-pin-trustee:latest os=scos base=quay.io/okd/scos-content:4.20.0-okd-scos.6-stream-coreos \
    kbc_image=quay.io/rkaufman/kbs-tpm-snp:v1 platform=gcp build oci-archive osbuild
    ```

2. Upload the image to GCP by running:
    ```bash
    ./scripts/GCP/upload_image_gcp.sh <BUCKET_NAME> <IMAGE_NAME>
    ```

3. Deploy the client by running:
    ```bash
    ./scripts/GCP/deploy-vm.sh -k <SSH_KEY> -b ./configs/luks.bu -n <VM_NAME> -i <IMAGE_NAME> -h <HOSTNAME>
    ```
    This will create the VM, perform attestation, and decrypt the disk using clevis-pin.


## Information About KBS, KBS-Client, and Clevis-Pin

These are modified versions of [trustee](https://github.com/iroykaufman/trustee/tree/addtpm) and the [guest component](https://github.com/iroykaufman/guest-components/tree/TPM-as-additional-device) to support the TPM as an additional device.

The changes in the guest component are also included in [PR#1093](https://github.com/confidential-containers/guest-components/pull/1093), and the changes in Trustee are related to [PR#851](https://github.com/confidential-containers/trustee/pull/851), where the most significant change is the removal of the trusted Attestation Key (AK) list.

This uses a modified version of `clevis-pin-trustee` that adds AK before performing attestation. The source code is available here: [clevis-pin-trustee](https://github.com/iroykaufman/clevis-pin-trustee/tree/create-tpm-ak)

## Attestation Policy

The policy only checks hardware for both SEV-SNP and TPM.

## Resource Policy

Verify that both devices are affirming and exist.


