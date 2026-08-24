#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

helm repo add cilium https://helm.cilium.io/
helm repo update

# Cilium default
# helm template cilium cilium/cilium --version 1.20.0 \
#     --namespace kube-system \
#     > cilium.yaml

# Cilium as a gateway-api provider
helm template cilium cilium/cilium --version 1.20.0 \
    --namespace kube-system \
    --set kubeProxyReplacement=true \
    --set gatewayAPI.enabled=true > cilium.yaml

if command -v gsed >/dev/null 2>&1; then
    SED="gsed"
else
    SED="sed"
fi

# replace default pod 10.X.X.X CIDR with 172.16.0.0/12
${SED} -i 's|10\.0\.0\.0/8|172.16.0.0/12|g' cilium.yaml

if grep -q '10\.0\.0\.0/8' cilium.yaml; then
    echo "error: unrewritten default CIDR 10.0.0.0/8 remains in cilium.yaml" >&2
    exit 1
fi

if ! grep -q '172\.16\.0\.0/12' cilium.yaml; then
    echo "error: expected pod CIDR 172.16.0.0/12 not found in cilium.yaml" >&2
    exit 1
fi

# add yamllint disable-file directive to the top of the file
${SED} -i '1s|^|# yamllint disable-file\n|' cilium.yaml
