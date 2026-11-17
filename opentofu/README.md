# OpenTofu

Manages Google Cloud and Azure AD resources with [OpenTofu](https://opentofu.org/).

## CI/CD Pipeline

Changes are applied via GitHub Actions with Workload Identity Federation.

### Triggers

| Trigger                                 | Action                                               |
| --------------------------------------- | ---------------------------------------------------- |
| PR to `main` with `opentofu/**` changes | Plan: comments diff on PR, fails on detected changes |
| PR merge                                | Apply: runs saved plan                               |
| `/test` or `/tofu plan` comment on PR   | Re-triggers plan                                     |

## State

Managed in GCS buckets in each respective project.
