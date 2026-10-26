#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

helm repo add rook-release https://charts.rook.io/release
helm repo add ceph-csi-operator https://ceph.github.io/ceph-csi-operator

# Operator Helm Chart
helm template rook-ceph rook-release/rook-ceph \
  --namespace rook-ceph > operator-helm.yaml

# CSI-Driver Helm Chart
helm template ceph-csi-drivers ceph-csi-operator/ceph-csi-drivers \
  --namespace rook-ceph \
  -f https://raw.githubusercontent.com/rook/rook/v1.21.0/deploy/charts/ceph-csi-drivers/values.yaml > csi-driver-helm.yaml

# Cluster Helm Chart
helm template rook-ceph-cluster rook-release/rook-ceph-cluster \
  --namespace rook-ceph \
  --set operatorNamespace=rook-ceph > cluster-helm.yaml