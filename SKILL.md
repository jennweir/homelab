---
name: homelab
description: Operational conventions for this HomeLab repository. Activates for any task that interacts with the CoreOS Kubernetes cluster, applies manifests, runs Ansible against the fleet, or changes cluster state.
---

# HomeLab Skill

Operational conventions for this HomeLab repository. Read this in full before
acting on cluster, manifest, or Ansible changes. The companion file
[AGENTS.md](AGENTS.md) expands on directory layout and common tasks.

## Cluster Inventory

| Cluster | Distribution         | Nodes                        | Storage   | KUBECONFIG  |
| ------- | -------------------- | ---------------------------- | --------- | ----------- |
| k8s-lab | Kubernetes on CoreOS | 3 control-plane (`cp-1/2/3`) | Rook-Ceph | `.kube/lab` |
| pi-lab  | operational          | 3 Raspberry Pis              | _(n/a)_   | _(n/a)_     |

GitOps: ArgoCD reconciles `k8s/manifests/` into the active cluster. All
Kustomize overlays under `k8s/manifests/` use the `lab` target for the k8s
cluster. Overlay (`pi-lab`) is active for the pi-lab cluster.

## Cluster Authentication

Export `KUBECONFIG` explicitly before any `kubectl`, `helm`, `kustomize`, or
`argocd` invocation:

```bash
export KUBECONFIG=.kube/lab   # repo-local; or ~/.kube/config
```

The kubeconfig grants **cluster-admin**. Caution rules:

- Prefer read-only commands (`get`, `describe`, `--dry-run=client`,
  `kustomize build`) when exploring.
- Confirm with the user before any mutating action: `apply`, `delete`,
  `patch`, `scale`, `drain`, `cordon`, `rollout restart`, `evict`.
- Mutations to ArgoCD-managed resources are reverted on the next sync — the
  correct fix is almost always a PR to `k8s/manifests/`, not a live
  `kubectl` change.

## Cluster Services

| Concern             | Implementation                                            |
| ------------------- | --------------------------------------------------------- |
| HA load balancer    | kube-vip                                                  |
| CNI / Gateway API   | Cilium                                                    |
| GitOps              | ArgoCD                                                    |
| Operator management | OLM v0 (active); OLM v1 kept for future migration/testing |
| Storage             | Rook-Ceph                                                 |
| Certificates / DNS  | cert-manager + Google Cloud DNS via GCP WIF               |
| Secrets             | External Secrets Operator + Google Secrets Manager (GSM)  |
| Authentication      | Azure AD OIDC (`k8s/manifests/platform/authentication/`)  |

## Repository Workflow

### Adding or editing a Kubernetes app

1. Place manifests under `k8s/manifests/<scope>/<app>/{base,overlays/<target>}`
   with a `kustomization.yaml` at each level.
2. If deploying via ArgoCD, register the app as an `Application` resource under
   `k8s/manifests/platform/argocd/applications/`.
3. Run `k8s-gitops-ci kustomize-fix -dir k8s/manifests/<app>` to normalize
   field ordering and prepend the `---` document marker.
4. Validate with `k8s-gitops-ci test --app k8s/manifests/<app> --cluster lab
--disable-checks avp`.
5. Follow manifest authoring rules: 2-space YAML indent, `---` document marker
   at top, `base/` holds the canonical resource, `overlays/<target>/` holds
   patches and additions.

### Secrets

- **Prefer [External Secrets Operator](k8s/manifests/platform/external-secrets-operator/) (ESO)**
  for any new secret: declare an `ExternalSecret` that pulls from Google
  Secrets Manager via GCP WIF. This keeps the secret reconciled, rotatable, and
  visible as a first-class Kubernetes resource.
- Fall back to **argocd-vault-plugin** placeholders (`<path:...#key>`) only when
  ESO cannot express the requirement (e.g., templated values injected into a
  non-Secret field, or bootstrap manifests that must render before ESO is
  available).
- Never commit plaintext secrets, kubeconfigs, tokens, or `.env` files.

### OpenTofu

- Active OpenTofu: `opentofu/k8s-lab/` — manages GCP WIF, Cloud DNS, and Azure
  AD app registrations.
- Active OpenTofu: `opentofu/pi-cluster/` — manages GCP WIF, Cloud DNS, and Azure AD app for the pi-lab cluster.
- State is stored in GCS backends. Authenticate with Application Default
  Credentials (`gcloud auth application-default login`); do not put credentials
  or tokens in the backend block.

### Ansible

- Installation playbooks:
  `k8s/installation/coreos-lab/ansible-playbooks/` (`install-k8s.yaml`,
  `install-cilium.yaml`, `reset-k8s.yaml`).
- Maintenance playbooks: `k8s/maintenance/coreos-lab/ansible-playbooks/`
  (`upgrade-v1.37.yaml`).
- Inventory files live alongside playbooks as `inventory` or
  `inventory-*.template`.
- Standard invocation:
  `ansible-playbook -i k8s/installation/coreos-lab/ansible-playbooks/inventory k8s/installation/coreos-lab/ansible-playbooks/install-k8s.yaml`

### CI Validation (k8s-gitops-ci)

- **Local iteration** (defaults to the working-tree diff — only changed files
  are validated):

  ```bash
  k8s-gitops-ci test --app k8s/manifests/<component> --cluster lab --disable-checks avp
  ```

- **Full repo scan**:

  ```bash
  k8s-gitops-ci test --all --disable-checks avp
  ```

- Always pass `--disable-checks avp` unless `VAULT_ADDR` and `VAULT_TOKEN` are
  exported — otherwise AVP placeholder resolution fails the overlay build with
  unrelated noise.
- **Scoped validation**: `k8s-gitops-ci test --app k8s/manifests/<app> --cluster
lab --disable-checks avp` (repeatable; `--app` alone validates every overlay
  of that app, `--cluster` alone validates every app targeting that cluster).
- Individual linters: `k8s-gitops-ci yamllint`, `k8s-gitops-ci shellcheck`,
  `k8s-gitops-ci markdownlint`, etc.

### Lint and formatting

`pre-commit` is authoritative ([`.pre-commit-config.yaml`](.pre-commit-config.yaml)):

- `yamllint`, `shellcheck`, `markdownlint`, `trailing-whitespace`,
  `end-of-file-fixer`, `check-yaml`, `check-merge-conflict`,
  `detect-private-key`
- Commit messages should follow Conventional Commits (`feat:`, `fix:`, `chore:`,
  `build(deps):`, `docs:`, ...).

YAML rules: 2-space indent, `---` document marker at top. Shell scripts:
`set -o errexit -o nounset -o pipefail`. All markdown files use **spaces**
(not tabs).

## Plan Mode vs Build Mode

- **Plan mode is read-only.** Never write to files while in plan mode. Only
  analyze, read, and propose.
- **Build mode is write-only.** Only write files (edit, create, delete) in build
  mode after the user has approved the plan.
- When in plan mode, present your findings, proposed changes, and reasoning.
  Let the user decide when to switch to build mode.

## Before Committing

- Validate changed files with `k8s-gitops-ci`.
- Ensure pre-commit hooks pass.
- **Never commit on the user's behalf.** Present your changes and let the user
  commit themselves.

## Out of Scope

- `okd/` — legacy OKD installer configs, VM XML definitions, and OKD-specific
  manifests from a previous cluster. Read for historical context only; do not
  use as reference for active cluster decisions.
- `staging/` — draft configs, not authoritative.
- `docs/` — operational reference, not deployed manifests.
- `.git/`, `CHANGELOG.md` (auto-maintained) — do not edit unless explicitly
  requested.
