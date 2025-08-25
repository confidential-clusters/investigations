#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <cluster_name>"
    echo "Example: $0 my-cluster"
    exit 1
fi

CLUSTER_NAME="$1"
EXPORT_DIR="${CLUSTER_NAME}"
TARBALL="${CLUSTER_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "Exporting cluster: $CLUSTER_NAME"
echo "Export directory: $EXPORT_DIR"

mkdir -p "$EXPORT_DIR"

echo "Stopping cluster $CLUSTER_NAME..."
kcli stop plan "$CLUSTER_NAME" || echo "Warning: Failed to stop cluster, continuing..."

VM=$(sudo virsh list --all --name | grep "^${CLUSTER_NAME}-ctlplane-0")
if [ ! -z "$VM" ]; then
	echo "Dumping XML for VM: $vm"
   sudo virsh dumpxml "$VM" > "$EXPORT_DIR/$VM.xml"
else
    echo "Error: No VMs found with prefix $CLUSTER_NAME-"
	 exit 1
fi

sudo virt-sparsify --in-place "$HOME/VirtualMachines/${VM}_0.img"

echo "Creating VM data directory..."
mkdir -p "$EXPORT_DIR/VirtualMachines"

echo "Copying VirtualMachines content..."
if [ -d ~/VirtualMachines ]; then
    cp -r ~/VirtualMachines/* "$EXPORT_DIR/VirtualMachines/" 2>/dev/null || echo "Warning: No VirtualMachines content to copy"
else
    echo "Warning: ~/VirtualMachines directory not found"
fi

echo "Copying cluster configuration..."
if [ -d ~/.kcli/clusters/"$CLUSTER_NAME" ]; then
    cp -r ~/.kcli/clusters/"$CLUSTER_NAME" "$EXPORT_DIR" || echo "Warning: No cluster config to copy"
else
    echo "Warning: ~/.kcli/clusters/$CLUSTER_NAME directory not found"
fi

echo "Extracting hosts entry..."
HOSTS_LINE=$(grep "api\.${CLUSTER_NAME}" /etc/hosts || true)
if [ -n "$HOSTS_LINE" ]; then
    echo "$HOSTS_LINE" > "$EXPORT_DIR/hosts"
    echo "Saved hosts entry: $HOSTS_LINE"
else
    echo "Error: No hosts entry found for api.${CLUSTER_NAME}.confidential-cluster.org"
	 exit 1
fi

echo "Creating tarball..."
tar -czf "$TARBALL" -C "$EXPORT_DIR" .

echo "Cleaning up temporary directory..."
rm -rf "$EXPORT_DIR"

echo "Export completed successfully!"
echo "Tarball created: $TARBALL"
echo "Size: $(du -h $TARBALL | cut -f1)"
