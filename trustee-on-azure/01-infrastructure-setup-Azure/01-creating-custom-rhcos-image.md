# Create Customized RHCOS image with 'trustee-attester' + 'aa-client-service' in Initrd

**Authors:** demeng@redhat.com, hhei@redhat.com \
**Jira Issue:** [VIRTWINKVM-1188](https://issues.redhat.com/browse/VIRTWINKVM-1188)  
**References:**
- [Custom CoreOS Disk Images](https://github.com/coreos/custom-coreos-disk-images)
- [Quay.io Repository](https://quay.io/repository/)
- [Latest RHCOS Images](https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/)

(Explanatory statement: Include trustee-attester binary file + .sh/.service files in the initrd to ensure the passphrase from the KBS-server can be fetched at the initramfs stage.).


### Step 1: Get authentication credentials
```bashV
Create ~/.config/containers/auth.json by clicking https://console.redhat.com/openshift/create/local, then copy or download secret.
```

### Step 2. Deploy fedora41 environment
```bash
sudo dnf update -y
sudo setenforce 0
sudo sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
sudo dnf install -y osbuild osbuild-tools \
         osbuild-ostree podman jq xfsprogs \
         e2fsprogs dosfstools genisoimage \
         squashfs-tools erofs-utils syslinux-nonlinux \
mkdir ~/test/create_cos_image; cd ~/test/create_cos_image
# copy the trustee-attester binary file to this path.
```


### Step 3. Get the relevant code
This repo contains several scripts that used to build container images for RHCOS.
```bash
git clone https://gitlab.com/6-dehan/initrd-trustee_plus.git
```

### Step 4. Pull container image and query the digest
```bash
podman pull quay.io/openshift-release-dev/ocp-v4.0-art-dev:419.96.202505021444-0-coreos

podman inspect quay.io/openshift-release-dev/ocp-v4.0-art-dev:419.96.202505021444-0-coreos | grep "Digest" 
        
        "Digest": "sha256:cfe9b9725b99707b25774a32d739ec121a699d43d7fb398f1ace82b041021864"

```

### Step 5. Edit Container File (reference link link):
```dockerfile
# from 419.96.202505021444-0-coreos 
FROM quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:cfe9b9725b99707b25774a32d739ec121a699d43d7fb398f1ace82b041021864

USER root
COPY initrd-trustee_plus/dracut/dracut.conf /etc/dracut.conf
COPY initrd-trustee_plus/dracut/65aaclient /usr/lib/dracut/modules.d/65aaclient
COPY initrd-trustee_plus/scripts/aa-client-service.sh /usr/bin/aa-client-service.sh
COPY initrd-trustee_plus/systemd/aa-client.service /usr/lib/systemd/system/aa-client.service
COPY trustee-attester /usr/bin/trustee-attester

RUN set -xeuo pipefail && \
    KERNEL_VERSION="$(basename $(ls -d /lib/modules/*))" && \
    raw_args="$(	lsinitrd /lib/modules/${KERNEL_VERSION}/initramfs.img | grep '^Arguments: ' | sed 's/^Arguments: //')" && \
    stock_arguments=$(echo "$raw_args" | sed "s/'//g") && \
    echo "Using kernel: $KERNEL_VERSION" && \
    echo "Arguments: $stock_arguments" && \
    mkdir -p /tmp/dracut /var/roothome && \
    dracut $stock_arguments && \
    mv -v "/lib/modules/${KERNEL_VERSION}/initramfs.img" "/lib/modules/${KERNEL_VERSION}/initramfs.stock.img" && \
    mv -v /boot/initramfs*.img "/lib/modules/${KERNEL_VERSION}/initramfs.img" && \
    ostree container commit

RUN lsinitrd /lib/modules/*/initramfs.img | grep "aa-client" 
```

### Step 6. Build container image with custom initramfs that includes trustee-attester and service
```bash
podman build -t rhcos_azure .
```

### Step 7. Convert to an ociarchive file, see https://github.com/coreos/custom-coreos-disk-images
```bash
# to pull from local storage
skopeo copy containers-storage:localhost/rhcos_azure:latest oci-archive:custom_azure-coreos.ociarchive
```

### Step 8. Generate a custom image for Azure
```bash
git clone https://github.com/coreos/custom-coreos-disk-images.git && cd custom-coreos-disk-images
ociarchive=/path/to/custom_azure-coreos.ociarchive 
platform=azure  # or 'qemu'
sudo ./custom-coreos-disk-images.sh --platforms $platform --ociarchive $ociarchive
```

### Step 9. Edit a proper ‘luks_rootfs.bu’ file
```yaml
# cat luks_rootfs.bu 
variant: fcos
version: 1.4.0
passwd:
  users:
    - name: core
      password_hash: $y$j9T$olqEnUo0IDevlLKg.8TgK0$JWEVZm25FHA.LYdWgckIQuULOPhbMMk.wQJx3nXU9u6
      ssh_authorized_keys:
        - ssh-rsa EXAMPLE_SSH_KEY user@hostname
storage:
  luks:
    - name: root
      label: luks-root
      device: /dev/disk/by-partlabel/root
      clevis:
        custom:
          needs_network: false
          pin: tpm2
          config: '{"pcr_bank":"sha256","pcr_ids":"7"}'
      wipe_volume: true
  filesystems:
    - device: /dev/mapper/root
      format: xfs
      wipe_filesystem: true
      label: root
  files:
    - path: /var/supersecret
      overwrite: true
      contents:
        inline: Schtroumpf!
systemd:
  units:
    - name: serial-getty@ttyS0.service
      dropins:
      - name: autologin-core.conf
        contents: |
          [Service]
          # Override Execstart in main unit
          ExecStart=
          # Add new Execstart with `-` prefix to ignore failure`
          ExecStart=-/usr/sbin/agetty --autologin core --noclear %I $TERM
```

### Step 10. Convert the luks_rootfs.bu -> luks_rootfs.ign
```bash
podman pull quay.io/coreos/butane

podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < luks_rootfs.bu  > my-custom-coreos-azure_2.ign
```

### Step 11. (Option) Check the ‘ignition.platform.id=azure’ 
```bash
note: Check the ‘ignition.platform.id=azure’ or the .vhd file would not identify .ign when use `az vm create ... ... --custom-data "$(cat ${ignition_path})"`. This is the key experience I hit. Please be aware that when the VM isn't configured as the ignition file on Azure.

# mount the vhd device and check the 'ignition.platform.id'
[user@host ~]$ sudo losetup -d /dev/loop0
[user@host ~]$ sudo mount /dev/loop0p3 /mnt
[user@host ~]$ cat /mnt/boot/loader/entries/ostree-1.conf 

# After checking, recover the env

[user@host ~]$ sudo umount /mnt
[user@host ~]$ losetup -a
[user@host ~]$ sudo losetup -d /dev/loop0
```
