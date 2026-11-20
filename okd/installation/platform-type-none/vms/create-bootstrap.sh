#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

COREOS="/var/lib/libvirt/images/coreos.iso"
VM_NAME="bootstrap"
VCPUS="4"
RAM_MB="18432"
STREAM="stable"
DISK="/dev/fedora/bootstrap-disk"

# system for when VMs are acting as servers
virt-install \
    --connect "qemu:///system" \
    --name "${VM_NAME}" \
    --vcpus "${VCPUS}" \
    --memory "${RAM_MB}" \
    --cdrom "${COREOS}" \
    --disk "${DISK}",format=raw \
    --noautoconsole \
    --network bridge=br0 \
    --graphics vnc \
    --os-variant="fedora-coreos-${STREAM}"
