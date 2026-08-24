#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

SCRIPTS_DIR="${REPO_ROOT}/scripts"
OUTPUT_DIR="${REPO_ROOT}/staging"

ARGOCD_VERSION="v3.5.1"
URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/ha/install.yaml"

RELEASE_NAME="${RELEASE_NAME:-argocd}"
export NAMESPACE="${NAMESPACE:-argocd}"

mkdir -p "${OUTPUT_DIR}"

echo "Creating manifests..."

"${SCRIPTS_DIR}/create-manifests.sh" "${URL}"

echo "Setting namespace '${NAMESPACE}' on namespaced resources..."

echo "Setting namespace '${NAMESPACE}' on namespaced resources..."

echo "Setting namespace '${NAMESPACE}' on namespaced resources..."

for file in "${OUTPUT_DIR}"/*.yaml; do
    filename="$(basename "${file}")"

    if [[ "${filename}" == "kustomization.yaml" ]]; then
        continue
    fi

    yq eval -i '
        with(
            select(
                .kind == "Namespace" or
                .kind == "CustomResourceDefinition" or
                .kind == "ClusterRole" or
                .kind == "ClusterRoleBinding"
            );
            del(.metadata.namespace)
        )
        |
        with(
            select(
                .kind != "Namespace" and
                .kind != "CustomResourceDefinition" and
                .kind != "ClusterRole" and
                .kind != "ClusterRoleBinding"
            );
            .metadata.namespace = strenv(NAMESPACE)
        )
    ' "${file}"
done

echo "Creating namespace.yaml..."

cat > "${OUTPUT_DIR}/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF

echo "Creating kustomization.yaml..."

cat > "${OUTPUT_DIR}/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
EOF

for file in "${OUTPUT_DIR}"/*.yaml; do
    filename="$(basename "${file}")"

    if [[ "${filename}" == "namespace.yaml" || "${filename}" == "kustomization.yaml" ]]; then
        continue
    fi

    echo "  - ${filename}" >> "${OUTPUT_DIR}/kustomization.yaml"
done

echo "Generated manifests in ${OUTPUT_DIR}"