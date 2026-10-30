# OpenTofu

Manages Google Cloud and Azure AD resources with [OpenTofu](https://opentofu.org/).

## Usage

### 1. Authenticate to Google Cloud

The GCS backend uses Application Default Credentials (ADC). Log in once per
machine (or when the ADC session expires):

```bash
gcloud auth application-default login
```

### 2. Apply IaC changes

```bash
cd opentofu/k8s-lab
tofu init
tofu plan
tofu apply
```

State is stored in the `jennweir-terraform-backend` GCS bucket:
`gs://jennweir-terraform-backend/terraform/state/k8s-lab/`.

`opentofu/pi-cluster/` is legacy (the pi-cluster is offline pending
redeployment) and is kept for historical reference.
