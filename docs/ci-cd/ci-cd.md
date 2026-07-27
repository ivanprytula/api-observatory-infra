# Infrastructure CI

The executable source of truth is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).
This repository validates infrastructure; application build, release, OIDC variables, and AWS
Stage 0 deployment workflows are owned by the app repository.

## Validation Gates

| Job | Purpose |
| --- | --- |
| Terraform format | Reject non-canonical HCL formatting |
| Terraform validate | Check environment configuration against pinned providers |
| TFLint | Detect Terraform errors and provider-specific issues |
| Checkov | Enforce IaC security controls and reviewed exceptions |
| Helm lint | Validate charts without deploying them |
| YAML lint | Validate Kubernetes, Ansible, and monitoring YAML |
| ShellCheck | Validate operational shell scripts |

Pre-commit configuration and the [`Justfile`](../../Justfile) own local command syntax. A passing
workflow proves static validation only; it does not prove that Terraform was applied, a workload was
deployed, or recovery was exercised.

## Cross-Repository Delivery

The app [CI/CD guide](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/ci-cd.md)
owns candidate images, release promotion, and protected deployment. Its
[OIDC setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md)
defines the required GitHub variables and IAM role responsibilities.

This infra repository owns the cloud resources and policies those workflows consume. The current
Terraform does not provision GitHub's OIDC provider or deployment roles, so they remain explicit
AWS Stage 0 prerequisites rather than implemented IaC claims.

## Change Rules

- Update the app deployment contract and consuming infrastructure together when images, ports,
  health endpoints, environment names, IAM, ingress, secrets, or telemetry change.
- Keep Checkov exceptions narrow and documented in [`TERRAFORM_CHECKS.md`](../../TERRAFORM_CHECKS.md).
- Review a Terraform plan before any apply; CI never authorizes a real cloud mutation.
- Preserve immutable image rollback and migration compatibility across delivery changes.
