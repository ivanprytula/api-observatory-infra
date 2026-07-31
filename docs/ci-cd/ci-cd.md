# Infrastructure CI

The executable source of truth is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).
This repository validates infrastructure; application CI, manual assurance, OIDC variables, and
AWS Stage 0 desired-state deployment workflows are owned by this infrastructure repository.

## Validation Gates

| Job | Purpose |
| --- | --- |
| Terraform format | Reject non-canonical HCL formatting |
| Terraform validate | Check environment configuration against pinned providers |
| TFLint | Detect Terraform errors and provider-specific issues |
| Checkov | Enforce IaC security controls and reviewed exceptions |
| Helm lint | Validate charts without deploying them |
| Workflow and secret checks | Lint GitHub Actions, reject mutable action references, and scan committed secrets |
| Python style | Lint and format-check repository scripts with Ruff |
| YAML lint | Validate Kubernetes, Ansible, monitoring, and workflow YAML |
| ShellCheck | Validate operational shell scripts |

Pre-commit configuration and the [`Justfile`](../../Justfile) own local command syntax. A passing
workflow proves static validation only; it does not prove that Terraform was applied, a workload was
deployed, or recovery was exercised.

Short-lived task branches target `main`. The stable `CI / Merge gate` fails unless every internal
validation job succeeds. Repository settings intentionally do not enforce checks or approvals yet,
so waiting for that gate is a maintainer policy rather than a GitHub restriction. Internal job names
and structure may evolve without changing the contributor or promotion contract.

## Cross-Repository Delivery

The application repository owns application CI, image smoke tests, and manual immutable-image
publication. Its publisher OIDC role can push and inspect ECR images only. This repository owns
infrastructure CI, the reviewed `images.lock.json` desired state, and protected manual deployment.
The lock binds the published app commit and tree to exact image digests; validation checks out that
commit rather than whichever app branch happens to be the default.
Its deployer OIDC role can inspect ECR digests and send commands only to the approved EC2 target;
the EC2 instance role separately pulls images from ECR.

This infra repository owns the cloud resources and policies those workflows consume. `aws-dev`
defines the GitHub OIDC provider/role (or accepts a pre-existing provider), immutable ECR
repositories, EC2 SSM instance role, and resource-scoped deployment permissions. Terraform still
requires a reviewed plan and explicit approval before these configured resources become a live claim.

## Change Rules

- Update the app deployment contract and consuming infrastructure together when images, ports,
  health endpoints, environment names, IAM, ingress, secrets, or telemetry change.
- Keep Checkov exceptions narrow and documented in [`TERRAFORM_CHECKS.md`](../../TERRAFORM_CHECKS.md).
- Review a Terraform plan before any apply; CI never authorizes a real cloud mutation.
- Preserve immutable image rollback and migration compatibility across delivery changes.

## App/Infra Contract Promotion

When a change affects published images, the runtime service contract, or deployment topology:

1. Merge the application PR into `main` and wait for the app repo `CI / Merge gate` to succeed.
2. Publish immutable `tree-<SHA>` images from the app repository using `publish-images.yml`.
3. Download the resulting `release-metadata-<commit-SHA>` artifact.
4. In `api-observatory-infra`, create a separate task branch from `main`, run
   `just promote-images <artifact-path>`, review the generated `images.lock.json`, and open an
   infra PR.
5. After infra CI passes, manually dispatch the approved Stage 0 deployment workflow in this repo.

Do not describe a lock-file change, Terraform plan, or published image as a completed deployment.
