#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

PROJECT_NUMBER=$(gcloud projects describe coreos-k8s-lab --format="value(projectNumber)")

gcloud iam workload-identity-pools create-cred-config \
    projects/"${PROJECT_NUMBER}"/locations/global/workloadIdentityPools/k8s-pool/providers/k8s-provider \
    --service-account="<REPLACE_WITH_GOOGLE_SA>@coreos-k8s-lab.iam.gserviceaccount.com" \
    --credential-source-file=/var/run/secrets/tokens/gcp-token \
    --output-file=gcp-wif-config.json
