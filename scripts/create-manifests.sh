#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <manifest-url-or-file>"
  exit 1
fi

MANIFESTSOURCE="$1"

# Resolve local files to absolute paths before descending into base/
if [[ -f "${MANIFESTSOURCE}" && "${MANIFESTSOURCE}" != /* ]]; then
  MANIFESTSOURCE="${PWD}/${MANIFESTSOURCE}"
fi

fetch() {
  if [[ -f "${MANIFESTSOURCE}" ]]; then
    cat -- "${MANIFESTSOURCE}"
  else
    curl -fsSL -- "${MANIFESTSOURCE}"
  fi
}

mkdir -p staging
pushd staging > /dev/null || exit 1

# Download/read manifests and separate into separate files
fetch | \
  yq --no-colors --prettyPrint '... comments=""' | \
  kubectl-slice -o . --template "{{ .kind | lower }}.yaml"

# if there is no deployment, skip it. otherwise, split the deployment up
if [[ ! -f "deployment.yaml" ]]; then
  echo "No deployment found in manifests, skipping kustomize"
else
  # Split the deployment up
  kubectl-slice -o . --template "{{ .kind | lower }}-{{ .metadata.name | lower }}.yaml" < deployment.yaml
  rm deployment.yaml

  kustomize create --autodetect
fi

# Format YAML
prettier . --write
popd > /dev/null || exit 1
