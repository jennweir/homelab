#!/usr/bin/env bash
set -euo pipefail

# find the USB device with `diskutil list` and pass it as the first argument;
# pass the target disk as the optional second argument, e.g.:
# ./create-fcos-k8s-iso.sh /dev/disk4
# ./create-fcos-k8s-iso.sh /dev/disk4 /dev/nvme0n1
USB_DEVICE="${1:-}"
DEST_DEVICE="${2:-/dev/nvme0n1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
KEY_SUFFIX="$(date +%Y%m%d)"
SSH_KEY_FILE="$HOME/.ssh/k8s-homelab-$KEY_SUFFIX"
INVENTORY_TEMPLATE="$REPO_ROOT/installation/k8s/ansible/playbooks/coreos-lab/inventory-coreos-lab.example"
INVENTORY_FILE="$REPO_ROOT/installation/k8s/ansible/playbooks/coreos-lab/inventory-coreos-lab"
TEMP_SECRETS_FILE="$(mktemp)"
trap 'rm -f "$TEMP_SECRETS_FILE"' EXIT

rm -f "$SSH_KEY_FILE" "$SSH_KEY_FILE.pub"
ssh-keygen -q -t ed25519 -N '' \
    -C "k8s-homelab-$KEY_SUFFIX" \
    -f "$SSH_KEY_FILE"

PASSWORD_HASH=$(sed -n "s/^PASSWORD_HASH='\(.*\)'$/\1/p" \
    "$REPO_ROOT/installation/k8s/coreos-lab/.secrets.env")
if [[ -z "$PASSWORD_HASH" ]]; then
    echo "error: PASSWORD_HASH is missing from coreos-lab/.secrets.env" >&2
    exit 1
fi

printf "SSH_PUBLIC_KEY='%s'\nPASSWORD_HASH='%s'\n" \
    "$(<"$SSH_KEY_FILE.pub")" "$PASSWORD_HASH" > "$TEMP_SECRETS_FILE"

sed "s|~/.ssh/k8s-homelab-YYYYMMDD|$SSH_KEY_FILE|g" \
    "$INVENTORY_TEMPLATE" > "$INVENTORY_FILE"

cd "$REPO_ROOT/installation/k8s"

SECRETS_FILE="$TEMP_SECRETS_FILE" ./create-ignition.sh lab

IGNITION_FILE="$REPO_ROOT/installation/k8s/coreos-lab/k8s.ign"
POST_INSTALL_SCRIPT="$REPO_ROOT/installation/k8s/coreos-lab/post-install-fcos-k8s.sh"
IMAGE_DIR="$REPO_ROOT/container-images/coreos-kubernetes"
ISO_DIR="$SCRIPT_DIR/output"

cd "$IMAGE_DIR"

podman machine start || true

FCOS_TAG=quay.io/fedora/fedora-coreos:stable
podman pull --platform linux/amd64 "$FCOS_TAG"

FCOS_ARCH=$(podman image inspect --format '{{.Architecture}}' "$FCOS_TAG")
if [[ "$FCOS_ARCH" != "amd64" ]]; then
    echo "error: expected an amd64 FCOS image, got $FCOS_ARCH" >&2
    exit 1
fi

FCOS_DIGEST=$(podman image inspect --format '{{.Digest}}' "$FCOS_TAG")
FCOS_IMAGE="${FCOS_TAG%:*}@${FCOS_DIGEST}"

podman image inspect \
    --format 'OS={{.Os}} ARCH={{.Architecture}} DIGEST={{.Digest}}' \
    "$FCOS_TAG"

podman build \
    --platform linux/amd64 \
    --build-arg FCOS_IMAGE="$FCOS_IMAGE" \
    --build-arg KUBERNETES_MINOR=v1.36 \
    --build-arg CRIO_MINOR=v1.36 \
    -t localhost/fcos-kubernetes:1.36 \
    ../../container-images/coreos-kubernetes

mkdir -p "$ISO_DIR"
OCI_ARCHIVE="$ISO_DIR/fcos-kubernetes.ociarchive"
podman save --format oci-archive \
    --output "$OCI_ARCHIVE" \
    localhost/fcos-kubernetes:1.36

podman run --rm \
    --platform linux/amd64 \
    -v "$ISO_DIR:/data" \
    -w /data \
    quay.io/coreos/coreos-installer:release \
    download -s stable -p metal -f iso

FCOS_ISO=$(find "$ISO_DIR" -maxdepth 1 -type f \
    -name 'fedora-coreos-*.iso' \
    ! -name 'fedora-coreos-k8s.x86_64.iso' \
    -print -quit)
if [[ -z "$FCOS_ISO" ]]; then
    echo "error: FCOS metal ISO was not downloaded" >&2
    exit 1
fi

EMBEDDED_ISO="$ISO_DIR/fedora-coreos-k8s.x86_64.iso"
rm -f "$EMBEDDED_ISO"
podman run --rm \
    --platform linux/amd64 \
    -v "$ISO_DIR:/data" \
    -v "$IGNITION_FILE:/ignition/k8s.ign:ro" \
    -v "$POST_INSTALL_SCRIPT:/ignition/post-install-fcos-k8s.sh:ro" \
    quay.io/coreos/coreos-installer:release \
    iso customize \
    --dest-ignition /ignition/k8s.ign \
    --dest-device "$DEST_DEVICE" \
    --post-install /ignition/post-install-fcos-k8s.sh \
    --output /data/fedora-coreos-k8s.x86_64.iso \
    "/data/$(basename "$FCOS_ISO")"

ISO_WITH_PAYLOAD="$ISO_DIR/fedora-coreos-k8s-payload.x86_64.iso"
rm -f "$ISO_WITH_PAYLOAD"
podman run --rm \
    --platform linux/amd64 \
    -v "$ISO_DIR:/data" \
    quay.io/fedora/fedora:latest \
    bash -c \
    'dnf install -y xorriso >/dev/null && \
    xorriso -indev /data/fedora-coreos-k8s.x86_64.iso \
        -outdev /data/fedora-coreos-k8s-payload.x86_64.iso \
        -boot_image any replay \
        -map /data/fcos-kubernetes.ociarchive /fcos-kubernetes.ociarchive \
        -commit -end'
mv "$ISO_WITH_PAYLOAD" "$EMBEDDED_ISO"

echo "created $EMBEDDED_ISO (automatic install target: $DEST_DEVICE)"
echo "SSH private key: $SSH_KEY_FILE"
echo "Ansible inventory: $INVENTORY_FILE"

if [[ -n "$USB_DEVICE" ]]; then
    if [[ "$USB_DEVICE" == /dev/rdisk* ]]; then
        DISK_DEVICE="/dev/disk${USB_DEVICE##*/rdisk}"
    elif [[ "$USB_DEVICE" == /dev/disk* ]]; then
        DISK_DEVICE="$USB_DEVICE"
    else
        echo "error: USB device must look like /dev/disk4 or /dev/rdisk4" >&2
        exit 1
    fi

    echo "Target USB device:"
    diskutil info "$DISK_DEVICE"
    read -r -p "Type WRITE to erase and write $DISK_DEVICE: " confirmation
    if [[ "$confirmation" != WRITE ]]; then
        echo "USB write cancelled"
        exit 0
    fi

    RAW_DEVICE="/dev/rdisk${DISK_DEVICE##*/disk}"
    diskutil unmountDisk "$DISK_DEVICE"
    sudo dd if="$EMBEDDED_ISO" of="$RAW_DEVICE" bs=4m
    sync
    diskutil eject "$DISK_DEVICE"
    echo "wrote $EMBEDDED_ISO to $DISK_DEVICE"
fi

