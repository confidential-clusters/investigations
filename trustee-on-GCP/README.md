# Remote attestation with PCRs and AMD SEV-SNP on GCP using RHCOS

This guide provides step-by-step instructions for setting up remote attestation using PCRs and AMD SEV-SNP on Google Cloud Platform (GCP) with Red Hat CoreOS (RHCOS). It covers the deployment of a Trustee server and the creation of a custom RHCOS client image that communicates with the Trustee service to fetch encryption keys and decrypt the root image.


## Prerequisites

1. Copy the pull secret from [Red Hat OpenShift](https://console.redhat.com/openshift/create/local) to ```~/.config/containers/auth.json``` into auths:quay.io:auth:&lt;pull_secret&gt;
2. Install [gcloud](https://cloud.google.com/sdk/docs/install)
3. Configure a subnet on GCP for the server and client by running ```./scripts/network_setup.sh```.


## Deploy the trustee server (KBS)

1. Run ```./scripts/deploy-trustee.sh -k <SSH_KEY> -b ./trustee/trustee.bu```. This will start the KBS with the correct configuration (the name of this VM must match the hostname of the server, so it has to match `KBS_HOSTNAME` in `./scripts/rh-coreos/usr/libexec/aa-client`).
2. Access the VM via SSH, then run ```sudo /usr/local/bin/populate_kbs.sh```. This will add the refrence value to Trustee.

## Deploy the client

1. Build a custom RHCOS image by running:
    ```bash
    ./scripts/build-rhcos-image.sh <IMAGE_NAME>
    ```

2. Upload the image to GCP by running:
    ```bash
    ./scripts/upload_image_gcp.sh <BUCKET_NAME> <IMAGE_NAME>
    ```

3. Deploy the client by running:
    ```bash
    ./scripts/deploy-client.sh -k <SSH_KEY> -b ./rh-coreos/luks.bu -n <VM_NAME> -i <IMAGE_NAME>
    ```
    This will create the VM, perform attestation and decrypt the disk.




## Info about the kbs and kbs-client

I use this version of [trustee](https://github.com/iroykaufman/trustee/tree/addtpm) and the [guest component](https://github.com/iroykaufman/guest-components/tree/TPM-as-additional-device).

Trustee includes [pr#851](https://github.com/confidential-containers/trustee/pull/851) with the following changes:

1. The guest component encrypts the public part of the AK in ASN.1 format, but trustee unmarshals it. The unmarshal part was replaced with an ASN.1 decrypt method.
2. The TPM verifier does not check the nonce in the TPM because the `report_data` contains a digest of the `runtime_data` instead of the nonce. This is because the TPM is an additional device. This is a temporary solution.


The changes in the guest component are included in this [PR#1093](https://github.com/confidential-containers/guest-components/pull/1093).

## Attestation Policy

The policy only checks hardware for both SEV-SNP and TPM.

## Resource Policy

Verify that both devices are affirming and exist.


## Demo

[![asciicast](https://asciinema.org/a/nsdsarO2ZTbXFjbh0wuNlohMt.svg)](https://asciinema.org/a/nsdsarO2ZTbXFjbh0wuNlohMt)

