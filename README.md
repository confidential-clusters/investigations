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
