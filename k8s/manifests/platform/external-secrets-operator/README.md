# external secrets operator

<https://external-secrets.io/main/>
<https://github.com/external-secrets/external-secrets>
<https://raw.githubusercontent.com/external-secrets/external-secrets/v2.12.0/deploy/crds/bundle.yaml>

## k8s lab cluster

Uses workload identity federation to eliminate use of long-lived service account token

<https://external-secrets.io/latest/api/spec/#external-secrets.io/v1.GCPWorkloadIdentityFederation>

## general helm

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm template eso external-secrets/external-secrets \
  --version 2.12.0 \
  --namespace external-secrets-operator \
  --set fullnameOverride=external-secrets \
  | sed '/helm.sh\/chart:/d; /app.kubernetes.io\/version:/d; /app.kubernetes.io\/managed-by:/d' \
  > k8s/manifests/platform/external-secrets-operator/helm.yaml

./scripts/create-manifests.sh k8s/manifests/platform/external-secrets-operator/components/helm/helm.yaml
```
