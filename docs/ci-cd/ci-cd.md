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
validation job succeeds. Before AWS delivery is enabled, protect `main` in both repositories by
requiring a pull request and the stable merge gate. Internal job names and structure may evolve
without changing the contributor or promotion contract.

## Cross-Repository Delivery

The application repository owns application CI, image smoke tests, and post-gate immutable-image
publication. Its publisher OIDC role can push and inspect ECR images only. This repository owns
the promotion script, infrastructure CI, the reviewed `images.lock.json` desired state, and
deployment of that merged state.
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
2. For a deployable change, app CI calls `publish-images.yml`, publishes immutable `tree-<SHA>`
   images, applies this repository's promotion script to current infra `main`, and opens or updates
   the single `automation/promote-aws-dev` PR.
3. Review the source identity, image digests, and green infra gate, then merge the PR to approve it.
4. Infra CI calls `deploy-aws-stage0.yml` for that merged lock. Manual dispatch only replays the
   lock already committed on `main`.

The downloaded release artifact and `just promote-images` remain a manual fallback, but their output
must go through a normal infra PR. Optional profiles also change through a separate infra PR.

Do not describe a lock-file change, Terraform plan, or published image as a completed deployment.
