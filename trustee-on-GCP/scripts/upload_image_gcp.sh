#!/bin/bash


BUCKET_NAME=$1
IMG_NAME=$2

## create a bucket to store the image
gsutil mb gs://${BUCKET_NAME}

gsutil cp ./${IMG_NAME}.tar-gcp.x86_64.tar.gz gs://${BUCKET_NAME}/

## create the image in GCP
gcloud compute images create ${IMG_NAME} \
    --source-uri gs://${BUCKET_NAME}/${IMG_NAME}.tar-gcp.x86_64.tar.gz \
    --description "My custom ${IMG_NAME} image" \
    --guest-os-features UEFI_COMPATIBLE,GVNIC,VIRTIO_SCSI_MULTIQUEUE,SEV_SNP_CAPABLE,TDX_CAPABLE 

