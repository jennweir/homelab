# Agent Instructions

This file is the entry point for AI agents working in this repository.

## Project Overview

- This repo manages a **bare-metal Kubernetes cluster** running on **CoreOS** (3 control-plane nodes) and a **pi-lab** (Raspberry Pis cluster).
- Applications are deployed via **ArgoCD GitOps**.
- Kubernetes manifests live in `k8s/manifests/` — this is the source of truth for active clusters.
- OpenTofu in `opentofu/k8s-lab/` provisions Google Cloud WIF, Cloud DNS, and the Azure AD app for the active cluster.
- **`okd/` is a historical artifact** from a previous OKD cluster. Do **not** rely on it when troubleshooting or making decisions about the active Kubernetes cluster.
- Agents must **never commit files** on the user's behalf. Always present diffs and let the user commit themselves.
- **Plan mode = read-only.** Never write to files in plan mode. Only write files in build mode.

## Repository Map

| Path                                   | Purpose                                                                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `k8s/`                                 | **Active** cluster config — manifests, installation, and maintenance for the CoreOS Kubernetes nodes                                           |
| `k8s/manifests/`                       | All Kustomize overlays: `platform/` (cert-manager, cilium, argocd, rook-ceph, etc.) and `apps/`                                                |
| `k8s/installation/`                    | FCOS ISO creation, ignition generation, and ansible playbooks for bootstrap                                                                    |
| `k8s/maintenance/`                     | Upgrade playbooks and node inventory                                                                                                           |
| `okd/`                                 | **Legacy** — OKD installer configs, VM XML, deployment scripts, and OKD-specific manifests from a previous cluster. Historical reference only. |
| `okd/manifests/platform/cluster-auth/` | Legacy OKD cluster auth config — do **not** use for active troubleshooting                                                                     |
| `opentofu/k8s-lab/`                    | **Active** OpenTofu — GCP WIF, Cloud DNS, and Azure AD app registrations                                                                       |
| `opentofu/pi-cluster/`                 | **Active** — pi-lab GCP/WIF infra for the pi-lab cluster                                                                                       |
| `container-images/`                    | Custom Containerfiles (`apache`, `coreos-kubernetes`, `argocd-sidecar-avp`)                                                                    |
| `scripts/`                             | Helper scripts (iSCSI, manifest generation, namespace cleanup, WIF config)                                                                     |
| `tests/`                               | Kustomize test overlays (WIF test, base)                                                                                                       |
| `docs/`                                | Operational docs (Proxmox, libvirt, firewalld, SELinux, storage, etc.)                                                                         |
| `staging/`                             | Staging / draft configs — **not** authoritative                                                                                                |

## Cluster Overview

The active cluster is vanilla **Kubernetes on CoreOS bare-metal nodes**:

- **Control-plane**: cp-1 (192.168.0.11), cp-2 (192.168.0.12), cp-3 (192.168.0.13)
- **HA load balancer**: kube-vip
- **CNI**: Cilium (with Gateway API)
- **GitOps**: ArgoCD
- **Operator management**: OLM v0 is active. OLM v1 (operator-controller) manifests are retained for future migration and past testing — do not assume they are live.
- **Storage**: Rook-Ceph
- **Certificates / DNS**: cert-manager with Google Cloud DNS (via GCP WIF)
- **Secrets**: External Secrets Operator (ESO) with Google Secrets Manager (GSM)
- **Authentication**: Azure AD OIDC via `k8s/manifests/platform/authentication/`

The **pi-lab** (pi-1/2/3 at 192.168.0.101–103) is operational. Treat its overlays as active.

## Conventions

### Kubernetes manifests (Kustomize)

- Layout per component: `k8s/manifests/<scope>/<name>/{base,overlays/<target>}` with a `kustomization.yaml` at each level.
- Active overlay target: `lab` (the active cluster). Pi-lab overlay: `pi-lab` (active cluster).
- After editing any `kustomization.yaml`, run `k8s-gitops-ci kustomize-fix -dir k8s/manifests/<component>` to normalize field ordering.
- **Secrets**: prefer **External Secrets Operator** (`ExternalSecret` resources). Never commit plaintext secrets. AVP placeholders (`<path:...#key>`) are used only when ESO cannot express the requirement.
- The `k8s-gitops-ci` tool is used for local validation — see [CI Validation](#ci-validation) below.

### Manifest authoring

- YAML indent: 2 spaces.
- `---` document marker required at top of files.
- Follow the Kustomize conventions: `base/` has the canonical resource, `overlays/<target>/` has patches and additions.

### OpenTofu

- Active OpenTofu: `opentofu/k8s-lab/` — manages GCP WIF, Cloud DNS, and Azure AD app for the Kubernetes cluster.
- Active OpenTofu: `opentofu/pi-cluster/` — manages GCP WIF, Cloud DNS, and Azure AD app for the pi-lab cluster.
- State is stored in GCS backends. Authenticate with Application Default Credentials (`gcloud auth application-default login`); do not put credentials or tokens in the backend block.

### Ansible

- Installation playbooks: `k8s/installation/coreos-lab/ansible-playbooks/` (`install-k8s.yaml`, `install-cilium.yaml`, `reset-k8s.yaml`).
- Maintenance playbooks: `k8s/maintenance/coreos-lab/ansible-playbooks/` (`upgrade-v1.37.yaml`).
- Inventory files live alongside playbooks as `inventory` or `inventory-*.template`.

### Shell, YAML, Markdown

- Shell scripts use `set -o errexit -o nounset -o pipefail`.
- YAML indent is 2 spaces; `---` document marker at top.
- Commit messages should follow Conventional Commits (`feat:`, `fix:`, `chore:`, `build(deps):`, `docs:`, ...).
- All markdown files must use **spaces** (not tabs).

### Pre-commit hooks

- `yamllint`, `shellcheck`, `markdownlint`, `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-merge-conflict`, `detect-private-key`.
- Linting config: `.github/linters/.yamllint.yaml`, `.markdownlint.json`.

## CI Validation

- **Local iteration**: `k8s-gitops-ci test --app k8s/manifests/<component> --cluster lab --disable-checks avp`
- **Full repo scan**: `k8s-gitops-ci test --all --disable-checks avp`.
- Always pass `--disable-checks avp` unless `VAULT_ADDR` and `VAULT_TOKEN` are exported.
- Individual linters: `k8s-gitops-ci yamllint`, `k8s-gitops-ci shellcheck`, `k8s-gitops-ci markdownlint`, etc.

## Before Committing

- Validate changed files with `k8s-gitops-ci`.
- Ensure pre-commit hooks pass.
- **Never auto-commit.** Present your changes and let the user commit.

## Plan Mode vs Build Mode

- **Plan mode is read-only.** Never write to files while in plan mode. Only analyze, read, and propose.
- **Build mode is write-only.** Only write files (edit, create, delete) in build mode after the user has approved the plan.
- When in plan mode, present your findings, proposed changes, and reasoning. Let the user decide when to switch to build mode.

## Out of Scope

- `okd/` — legacy OKD installer configs, VM XML definitions, and OKD-specific manifests from a previous cluster. Read for historical context only; do **not** use as reference for active cluster decisions.
- `staging/` — draft configs, not authoritative.
- `docs/` — operational reference, not deployed manifests.
- `.git/`, `CHANGELOG.md` (auto-maintained) — do not edit unless explicitly requested.
