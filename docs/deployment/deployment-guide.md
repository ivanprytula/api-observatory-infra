# AWS Stage 0 Deployment Guide

AWS Stage 0 is the primary portfolio direction: immutable ECR images and local PostgreSQL containers
on one EC2 Docker Compose host. Encrypted EBS volumes hold runtime data; private S3 holds retained
backup artifacts. Configuration and workflows exist, but no completed live deployment is claimed.

The rollout is a single-host in-place recreate with a coordinated image set and best-effort
rollback. It is not rolling, blue/green, canary, or zero-downtime delivery: there is no parallel
stack or traffic switch, and Compose replaces changed service containers on the existing host. For
the canonical app-to-infra delivery checklist, see the app repository's
[Canonical Onboarding and Delivery Checklist](https://github.com/ivanprytula/api-observatory/blob/main/docs/05-development/onboarding-and-delivery-checklist.md).

Stage 0 is private/admin-only: Systems Manager is the administration and verification path. It has
no public DNS, TLS, load balancer, or inbound application port until a separately approved public
demo requirement exists.

Real provisioning, deployment, restore, and teardown mutate an account and may create cost. Review
the exact plan/targets and obtain explicit approval before running them. The
[`Justfile`](../../Justfile) owns supported named workflows; native Terraform and Ansible commands
below own explicit operator work.

Before any `aws-dev` Terraform initialization, bootstrap the versioned, encrypted, private S3 state
bucket described in the [README state-backend setup](../../README.md#bootstrap-the-aws-state-backend).
The backend uses Terraform's native S3 lockfile (`use_lockfile = true`); no DynamoDB lock table is
required.

## Promotion model

The infrastructure repository uses a deliberately simple promotion model:

| Promotion lane | Current meaning | Current implementation |
| --- | --- | --- |
| dev | The only active deployment lane. | `aws-dev` is the current concrete target for AWS Stage 0. |
| stage | Reserved for a later staged environment. | Not active yet. |
| prod-like | Reserved for a later production-like environment. | Not active yet. |

The concrete environment name remains `aws-dev` for now to minimize refactoring. The logical lane is `dev`. Future multi-cloud or higher-tier environments should keep the same lane model and use a concrete target name such as `<cloud>-dev`, `<cloud>-stage`, or `<cloud>-prod-like`.

For the full promotion contract and naming guidance, see [promotion model](promotion-model.md).

## Ownership and Contract

- The app repository owns code, Dockerfiles, local Compose, health behavior, and the portable
  [release manifest](https://github.com/ivanprytula/api-observatory/blob/main/release/services.json).
- This repository owns `aws-dev` Terraform, EC2/ECR/IAM/networking/S3, Ansible host provisioning, and
  runtime secret delivery. The instance role reads service-scoped SecureString parameters under
  `/api-observatory/aws-dev/runtime/{ingestor-db,ingestor,dashboard,backup}` and writes root-owned files
  under `/opt/api-observatory-stage0/.runtime/`.
- This repository owns [`images.lock.json`](../../environments/aws-dev/images.lock.json), the AWS
  Compose topology, and deployment scripts. A reviewed lock-file change is the environment desired state.

| Service | Runtime | ECR repository suffix | Port | Health/readiness |
| --- | --- | --- | ---: | --- |
| ingestor | Core | `api-observatory/ingestor` | 8000 | `/health`, `/readyz` |
| inference | Optional `inference` profile | `api-observatory/inference` | 8001 | `/health`, `/readyz` |
| dashboard | Core | `api-observatory/dashboard` | 8501 | `/_stcore/health` |

MCP remains a local stdio process and is not deployed.

## Preparation Gates

1. Validate all three images and the app/infra contract locally.
2. From `terraform/environments/aws-dev`, create and review the plan with the native Terraform commands:

   ```bash
   terraform init -reconfigure -upgrade -backend-config=backend.s3.hcl
   terraform validate
   terraform plan -input=false -var-file=terraform.tfvars -out=tfplan
   terraform show tfplan
   ```

   Apply only the reviewed saved plan after explicit approval:

   ```bash
   terraform apply tfplan
   ```

   `terraform apply` mutates the selected AWS account and can create cost.
3. Review Checkov exceptions, expected cost, state retention, and teardown.
4. Apply the reviewed Terraform only after approval. It creates ECR, GitHub OIDC/role configuration
   (or accepts an existing provider ARN), the EC2 instance role, encrypted backup bucket, and runtime
   storage boundary.
5. Bootstrap the new or replaced host through SSM. Run this preflight from `ansible/`; it obtains
   Terraform outputs without writing a real instance ID into tracked inventory:

   ```bash
   ansible-playbook -i inventory/hosts.yml --limit aws_dev \
     -e "ansible_host=$(terraform -chdir=../terraform/environments/aws-dev output -raw instance_id)" \
     -e "ansible_aws_ssm_bucket_name=$(terraform -chdir=../terraform/environments/aws-dev output -raw stage0_ansible_transfer_bucket)" \
     --check --diff \
     playbooks/bootstrap-aws-stage0.yml
   ```

   After reviewing the check/diff output and obtaining approval, run the same operation without
   `--check --diff`:

   ```bash
   ansible-playbook -i inventory/hosts.yml --limit aws_dev \
     -e "ansible_host=$(terraform -chdir=../terraform/environments/aws-dev output -raw instance_id)" \
     -e "ansible_aws_ssm_bucket_name=$(terraform -chdir=../terraform/environments/aws-dev output -raw stage0_ansible_transfer_bucket)" \
     playbooks/bootstrap-aws-stage0.yml
   ```

   The controller needs `session-manager-plugin` plus S3 read/write/delete access to the dedicated,
   short-lived Ansible transfer bucket. The instance downloads only controller-generated presigned
   URLs; it does not need an SSH key or inbound port 22.
6. Create the required SecureString values outside Terraform and repository/workflow files. Bootstrap
   is deliberately secret-free; it only prepares Docker, protected directories, and helper commands.
7. A deployable application change that passes the app `main` merge gate calls the reusable image
   publisher. It checks out current infra `main`, runs this repository's promotion script, and opens
   or updates `automation/promote-aws-dev`. Review the deterministic `images.lock.json` diff,
   including its source commit, tree, and digests, then merge that green PR to approve deployment.
   Optional profiles are preserved from infra `main` and change only through a separate infra PR.
8. A green infra `main` CI run automatically calls the
   [AWS Stage 0 deployment workflow](../../.github/workflows/deploy-aws-stage0.yml) when the merged
   commit changes the `aws-dev` lock. The workflow renders runtime files on the host, copies the
   reviewed Compose assets, pulls only the locked digests with the EC2 role, runs migrations, and
   executes readiness and authenticated smoke checks. Manual dispatch only replays the desired state
   already committed on `main`.

For a first release or promotion-service outage, download the app publisher's
`release-metadata-<commit-SHA>` artifact, create a normal infra task branch, and run
`just promote-images <artifact-path>`. Review and merge that PR through the same CI and deployment
path; never write the lock directly to `main`.

The app [OIDC setup](https://github.com/ivanprytula/api-observatory/blob/main/docs/06-ci-cd/github-secrets-setup.md)
owns repository variables and least-privilege role responsibilities.

## Delivery and Verification

The app repository publishes CI-checked `tree-<SHA>` images and machine-readable release metadata to
ECR/GitHub Actions after a deployable `main` change passes its merge gate. Promotion is one bot-owned
infra PR that changes `images.lock.json`; only the current app `main` tip may update that PR. Merging the reviewed
lock is the deployment approval. Infra CI then checks out the locked app commit, verifies its tree and
image digests, and applies that exact desired state through Systems Manager. Both AWS enablement
variables remain explicit kill switches, and a manual dispatch can only replay current infra `main`.

The committed all-zero image lock is only a pre-provisioning schema fixture. Infrastructure CI labels
that exception explicitly; the deployment workflow rejects it. Before enabling any AWS delivery gate,
publish a CI-green image set and review a lock-file change containing its real tree SHA and ECR digests.

Capture redacted evidence for the deployed image identity, health/readiness, dashboard-to-ingestor
connection, authenticated critical path, signal correlation, dependency recovery, and infrastructure state.
Configuration or a successful plan alone is not deployment proof.

## Rollback and Teardown

Canonical rollback reverts the image-lock commit through a reviewed PR; its merge invokes the same
desired-state deployment. The
rollout also attempts to restore the previous deployment environment when readiness fails, but that
is best-effort only: it does not downgrade either database and cannot make an incompatible schema
contraction safe. Application migrations must remain backward compatible with both image sets.

Before temporary deployment, identify every billable resource and retention decision. Teardown
requires a reviewed destroy plan and explicit destructive-action approval. Afterwards verify EC2,
EBS volumes, ECR storage, S3 backups, public IPs, logs, KMS resources, and remote state against the intended retained
set. Stopping EC2 alone does not stop all cost.

Use [platform observability](../operations/observability.md) and the
[recovery guide](../operations/recovery-guide.md) for runtime evidence. Azure remains
secondary/reference and must not be mixed into the AWS Stage 0 claim.

## Optional Profiles

Bootstrap prepares the host only; the first approved infra desired-state deployment renders runtime files and starts `ingestor-db`,
`ingestor`, and `dashboard`. To enable an optional dependency, add its name to `enabled_profiles` in
a separate reviewed infrastructure PR, add the corresponding Parameter Store values, then merge the
profile change to run the desired-state deployment. Automated image promotion preserves the profile
selection already on `main`. Supported profiles are `inference`, `cache`, `broker`, and
`monitoring`. Direct notification delivery remains the default; `notification-consumer` starts only
with the broker profile. No optional profile is required for the core service claim.

`enabled_profiles` in `images.lock.json` is the desired-state source for these profiles. The
deployment workflow passes it to the rollout, which pulls, starts, and verifies the selected profile;
the inference profile also runs its migration before startup. Stage 0 dependency images are pinned by
registry digest in the deployment Compose file and change only through a reviewed infra PR. Selected
services use restart policies; HTTP services and dependencies expose health checks, while the
notification consumer's long-running process state remains its container health boundary.

## Backup and Disposable Restore

The required `/api-observatory/aws-dev/runtime/backup/AWS_S3_BUCKET` Parameter Store value names
the Terraform-created backup bucket. After core CD, run
`sudo /usr/local/sbin/api-observatory-stage0-backup-postgres` to create a custom-format dump through
the running `ingestor-db` container and upload it under `postgres/`. To rehearse recovery without
overwriting the application database, run
`sudo /usr/local/sbin/api-observatory-stage0-restore-postgres postgres/<backup-key> [disposable_db]`.
Inspect the disposable database and explicitly drop it only after the exercise. These commands are
not evidence until executed against an approved target and recorded with redacted output.
