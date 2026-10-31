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

For the pi-lab cluster, see `opentofu/pi-cluster/` for GCP/WIF and Azure AD app registration infrastructure.
