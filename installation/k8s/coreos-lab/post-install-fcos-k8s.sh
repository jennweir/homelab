#!/usr/bin/env bash
set -euo pipefail

DEST_ROOT=/mnt
if [[ ! -x "$DEST_ROOT/usr/bin/rpm-ostree" ]]; then
    DEST_ROOT=/sysroot
fi

ARCHIVE=$(find /run/media /media /mnt -type f \
    -name 'fcos-kubernetes.ociarchive' -print -quit 2>/dev/null)
if [[ -z "$ARCHIVE" ]]; then
    echo "custom Kubernetes image archive was not found on the installer media" >&2
    exit 1
fi

# world-readable: rpm-ostree drops privileges during OCI import (rpm-ostree#5408)
install -D -m 0644 "$ARCHIVE" "$DEST_ROOT/var/lib/fcos-kubernetes.ociarchive"
install -D -m 0644 /dev/null \
    "$DEST_ROOT/etc/systemd/system/fcos-kubernetes-rebase.service"
cat > "$DEST_ROOT/etc/systemd/system/fcos-kubernetes-rebase.service" <<'UNIT'
[Unit]
Description=Rebase to the Kubernetes FCOS image from installer media
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/fcos-kubernetes-rebased

[Service]
Type=oneshot
ExecStart=/usr/bin/rpm-ostree rebase --bypass-driver ostree-unverified-image:oci-archive:/var/lib/fcos-kubernetes.ociarchive
ExecStartPost=/usr/bin/touch /var/lib/fcos-kubernetes-rebased
ExecStartPost=/usr/bin/systemctl reboot --no-wall
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
ln -s ../fcos-kubernetes-rebase.service \
    "$DEST_ROOT/etc/systemd/system/multi-user.target.wants/fcos-kubernetes-rebase.service"
