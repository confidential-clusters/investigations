# Investigations for Confidential Clusters

Work in progress documents about Confidential Clusters.

## Start fcos VM
```bash
scripts/install_vm.sh  -b config.bu -k "$(cat coreos.key.pub)"
```

## Remove fcos VM
```bash
scripts/uninstall_vm.sh  -n <vm_name>"
```

## Example with local VMs, attestation and disk encryption

Currently, ignition does not support encrypting the disk using trustee (see this 
[RFC](https://github.com/coreos/ignition/issues/2099) for more details). Therefore, we need to build a custom initramfs
which contains the trustee attester, and the KBS information hardcoded in the setup script.

Build the Fedora Coreos or Centos Stream Coreos image with the custom initrd:
```bash
cd coreos
# Centos Stream image
just build oci-archive osbuild-qemu
just --os=fcos build oci-archive osbuild-qemu
```

In order to understand which image needs to be used for a specific OKD version, you can use this command:
```bash
$ oc adm release info --image-for=stream-coreos quay.io/okd/scos-release:4.19.0-okd-scos.1
```
Where the image is the okd release from where you get the `openshift-installer`.



In this example, we use 2 VMs, the first for running the trustee server while the second VM has been attested and its
root disk is encrypted using the secret stored in Trustee.

As already mentioned, the information are hardcoded in the initial script since we lack ignition support. Hence, if the
entire setup feels rigid and manual, it will improve in the future with the ignition extension.

Both VMs are created from the same image in order to retrieve the PCR registers from the TPM. This step and the VM can
be avoided once we are able to pre-calculate the PCRs.

The script `create_vms.sh`:
  1. launches the first VM with Trustee
  2. waits until Trustee is reachable at port `8080`
  3. populates the KBS with the reference values, the attestation policy for register 4, 7, and 14, and the secret
  4. creates the second VM which will perform the attestation in order to encrypt its root disk

```bash
scripts/create-vms.sh coreos.key.pub 
```

### Example with the Confidential Clusters operator and a local VM

If you have deployed Confidential Clusters with Trustee, and its KBS is available at port `8080`, and the VM PCR values are configured with Trustee, you can instead run

```bash
EXISTING_TRUSTEE=yes scripts/create-vms.sh coreos.key.pub
```

to skip the creation of the former VM.

## Deploying OKD with kcli

You can use [kcli](https://kcli.readthedocs.io/en/latest/) to deploy an OKD cluster. It will provision the control plane
and worker nodes on the local libvirt environment.

Currently, this setup works if you relies on the branch [cocl-kcli](https://github.com/alicefr/kcli/tree/cocl-kcli)
since it includes the fixes for the [TPM](https://github.com/karmab/kcli/pull/825) and to use a
[custom url for the coreos image](https://github.com/karmab/kcli/pull/826).
You can enable kcli by:
```bash
git clone https://github.com/alicefr/kcli.git -b cocl-kcli
cd  kcli
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
```

The custom SCOS image can be hosted locally using the container image `httpd`:
```bash
podman run -td --rm -p 8000:80\
    -v "$PWD":/usr/local/apache2/htdocs/ \
    docker.io/library/httpd:2
```

### Base Configuration
* Start from the configuration [cluster.yaml](okd/cluster.yaml)
* Customize it by specifying:
  * SSH public key
  * custom SCOS image
```bash
kcli create kube openshift \
  --paramfile ~/src/investigations/okd/cluster.yaml \
  -P image_url=http://localhost:8000/disk.qcow2 \
  -P pub_key=/home/afrosi/.ssh/okd.pub
```

Additional control planes and workers can be added with the `scale` command:
```bash
kcli scale kube openshift -w 1 cocl --paramfile okd/cluster.yaml
```
