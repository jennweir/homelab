# OLM Installation

## Prerequisite

- OLM v1 requires cert-manager to be installed
- OLM install.sh script located in the operator-framework repo explains this process
  <https://github.com/operator-framework/operator-controller/releases/latest/download/install.sh>

```bash
./scripts/create-manifests.sh https://github.com/operator-framework/operator-controller/releases/download/v1.11.0/operator-controller.yaml
./scripts/create-manifests.sh https://github.com/operator-framework/operator-controller/releases/download/v1.11.0/default-catalogs.yaml
```

Ref:

- <https://operator-framework.github.io/operator-controller/getting-started/olmv1_getting_started/>
