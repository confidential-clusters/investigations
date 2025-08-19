#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <tarball_path>"
    echo "Example: $0 my-cluster-export-20231201-143000.tar.gz"
    exit 1
fi

TARBALL="$1"
TARBALL_BASENAME=$(basename "$TARBALL" .tar.gz)
CLUSTER_NAME=$(echo "$TARBALL_BASENAME" | sed 's/-[0-9]\{8\}-[0-9]\{6\}$//')
IMPORT_DIR="$CLUSTER_NAME"

if [ ! -f "$TARBALL" ]; then
    echo "Error: Tarball $TARBALL not found"
    exit 1
fi

echo "Detected cluster name from tarball: $CLUSTER_NAME"

echo "Importing cluster from: $TARBALL"
echo "Import directory: $IMPORT_DIR"

mkdir -p "$IMPORT_DIR"

echo "Extracting tarball..."
tar -xzf "$TARBALL" -C "$IMPORT_DIR"

echo "Ensuring required directories exist..."
mkdir -p $HOME/VirtualMachines
mkdir -p $HOME/.kcli/clusters

echo "Restoring VirtualMachines content..."
if [ -d "$IMPORT_DIR/VirtualMachines" ]; then
    cp -r "$IMPORT_DIR/VirtualMachines"/* $HOME/VirtualMachines
else
    echo "Error: No VirtualMachines directory found in tarball"
	 exit 1
fi

echo "Restoring cluster $CLUSTER_NAME content..."
if [ -d "$IMPORT_DIR/$CLUSTER_NAME" ]; then
    cp -r "$IMPORT_DIR/$CLUSTER_NAME" "$HOME/.kcli/clusters"
else
    echo "Error: No VirtualMachines directory found in tarball"
	 exit 1
fi

sudo virsh define "$IMPORT_DIR/$CLUSTER_NAME-ctlplane-0.xml"

echo "Checking hosts file..."
if [ -f "$IMPORT_DIR/hosts" ]; then
    SAVED_HOSTS_LINE=$(cat "$IMPORT_DIR/hosts")
    CURRENT_HOSTS_LINE=$(grep "api\.${CLUSTER_NAME}" /etc/hosts 2>/dev/null || true)
    if [ -n "$CURRENT_HOSTS_LINE" ]; then
        if [ "$CURRENT_HOSTS_LINE" = "$SAVED_HOSTS_LINE" ]; then
            echo "Hosts entry already exists and matches, no change needed"
        else
            echo "Hosts entry exists but differs, replacing..."
            sudo sed -i "/api\.${CLUSTER_NAME}/c\\${SAVED_HOSTS_LINE}" /etc/hosts
            echo "Updated hosts entry: $SAVED_HOSTS_LINE"
        fi
    else
        echo "$SAVED_HOSTS_LINE" | sudo tee -a /etc/hosts > /dev/null
        echo "Added hosts entry: $SAVED_HOSTS_LINE"
    fi
else
    echo "Warning: No hosts file found in tarball"
fi

echo "Setting correct permissions..."
chown -R "$USER:$USER" ~/VirtualMachines ~/.kcli/clusters 2>/dev/null || true

echo "Cleaning up temporary directory..."
rm -rf "$IMPORT_DIR"

kcli start plan $CLUSTER_NAME
echo "Import completed successfully!"

KUBECONFIG=$HOME/.kcli/clusters/$CLUSTER_NAME/auth/kubeconfig
API_SERVER=$(oc whoami --show-server)

until curl -k --silent --fail "$API_SERVER/healthz"; do
    echo "Waiting for API server..."
    sleep 5
done

echo "API server is up!"
echo "set export KUBECONFIG=$KUBECONFIG"
