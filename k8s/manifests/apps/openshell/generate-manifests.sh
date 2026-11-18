#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

helm template openshell \
  oci://ghcr.io/nvidia/openshell/helm-chart \
  --version 0.1.8 \
  --namespace openshell \
  --set agentSandbox.preflight.enabled=false \
  | sed '/helm.sh\//d; /app.kubernetes.io\/version:/d; /app.kubernetes.io\/managed-by:/d; /app.kubernetes.io\/created-by:/d; ' \
  > openshell.yaml
