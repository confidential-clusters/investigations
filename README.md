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

### Import OKD cluster
You can import a cluster by:
```
$ okd/import-cluster.sh cocl-20250825-162523.tar.gz
Detected cluster name from tarball: cocl
Importing cluster from: cocl-20250825-162523.tar.gz
Import directory: cocl
Extracting tarball...
Ensuring required directories exist...
Restoring VirtualMachines content...
Restoring cluster cocl content...
Domain 'cocl-ctlplane-0' defined from cocl/cocl-ctlplane-0.xml

Checking hosts file...
Hosts entry already exists and matches, no change needed
Setting correct permissions...
Cleaning up temporary directory...
Starting vms from plan cocl
cocl-ctlplane-0 started on local!
Plan cocl started!
Import completed successfully!
Waiting for API server...
Waiting for API server...
[..]
Waiting for API server...
okAPI server is up!
set export KUBECONFIG=/home/afrosi/.kcli/clusters/cocl/auth/kubeconfig
```

*Note: with the current setup, the control planes aren't using the modified SCOS image, hence they don't go through only
attestation. Only the workers for now uses the custom SCOS image*

Create worker:
```
 kcli scale kube openshift -w 1 cocl --paramfile okd/cluster.yaml 
Scaling on client local
Using separate worker image for scaling: /home/afrosi/images/scos-qemu.x86_64.qcow2
Deploying Vms...
cocl-ctlplane-0 skipped on local!
Deploying Vms...
Using image path although it's not in a pool
Merging ignition data from existing /home/afrosi/.kcli/clusters/cocl/worker.ign for cocl-worker-0
cocl-worker-0 deployed on local
Workers nodes will join the cluster in a few minutes
```

## How to create the OKD cluster
* Start from the configuration [cluster.yaml](okd/cluster.yaml)
* Customize it by specifying:
  * SSH public key
  * custom SCOS image
```bash
$ kcli create kube openshift \
    --paramfile okd/cluster.yaml cocl \
    --force  -P pub_key=$HOME/.ssh/okd.pub\
    -P worker_image=$HOME/images/scos-qemu.x86_64.qcow2
```

## Export the cluster
You can create a tarball including the artifacts for the created cluster by:
```bash
$ okd/export-cluster.sh cocl
```

*Note: the cluster should have already finished to bootstrap since the export script only dump the first control plane*
