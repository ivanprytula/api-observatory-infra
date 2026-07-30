# API Observatory — Infrastructure

Multi-cloud Infrastructure-as-Code for the [API Observatory](https://github.com/ivanprytula/api-observatory) platform.

AWS is the primary portfolio deployment direction; Azure remains secondary/reference
infrastructure. The [evolution plan](docs/architecture/evolution-plan.md) owns platform stages and
adoption triggers, while the [baseline](docs/architecture/baseline-checklist.md) owns durable
security/SRE controls.

For the whole product-to-platform story, start with the app-owned
[Application Lifecycle and SDLC](https://github.com/ivanprytula/api-observatory/blob/main/docs/01-intro/application-lifecycle.md).
It follows one vertical slice from idea and planning through development, delivery, operations,
maintenance, and transformation, with direct links back to this repository at each platform stage.

## Repository Structure

```text
terraform/
  environments/
    azure-dev/           Azure cloud (B1s free tier)
    aws-dev/             AWS cloud (t2.micro free tier)
ansible/                 Playbooks, inventory (multi-cloud), roles
kubernetes/              K8s manifests, Helm charts, overlays (cloud-neutral)
monitoring/              Prometheus, Alertmanager, Grafana (cloud-neutral)
security/                Seccomp profiles
scripts/                 Provisioning, backup/restore (per-cloud variants)
docs/                    CI, deployment, observability, recovery, evolution, baseline
```

Sandbox environments (floci-az, floci-aws) live in the **app repo** — they're dev tooling.

## Working with the Repository

The [`Justfile`](Justfile) owns Terraform, Ansible, Kubernetes, Helm, backup/restore, and validation
command syntax. Start with static validation and a reviewed Terraform plan. Any apply, deployment,
restore, chaos action, or teardown requires explicit target review and approval.

## Contract with App Repo

| Contract | AWS primary Stage 0 | Azure secondary/reference |
| --- | --- | --- |
| Image registry | ECR | ACR |
| Deployable services | ingestor `:8000`, inference `:8001`, dashboard `:8501` | Same application contract |
| Image tag format | `tree-<SHA>` | `tree-<SHA>` |
| Compute | EC2 + Docker Compose | VM + Docker Compose |
| Config schema | App repo environment contract | Same |

## Platform Direction

Stage 0 co-locates the application images and PostgreSQL containers on one EC2 Docker Compose host,
with ECR, Parameter Store, and retained S3 backups as its AWS control plane. This repository holds
the AWS desired-state image lock and deployment topology. The host is operated
privately through Systems Manager; public ingress, DNS, and TLS are deferred. This is a
planned/configured path, not a completed deployment. ECS/Fargate and managed databases require
measured operational pressure; Kubernetes remains a later evidence-triggered stage.

AWS delivery remains disabled by default. A real deployment requires an approved Terraform plan,
published CI-green images, reviewed runtime SecureString values, and a non-placeholder
`environments/aws-dev/images.lock.json`. The [deployment guide](docs/deployment/deployment-guide.md)
documents the explicit Terraform, Ansible bootstrap, and manually dispatched CD workflow.

## Prerequisites

The app repository owns the core local runtime; this repository adds infrastructure/operator tools.
Install only the row matching the work you will perform.

| Work | Developer-machine dependencies |
| --- | --- |
| Application work or local Compose verification | Docker Engine/Desktop + Compose v2, Python 3.14.6, `uv`, `just`, Git, `curl` — see the app [Setup Guide](https://github.com/ivanprytula/api-observatory/blob/main/docs/04-setup/setup-guide.md) |
| Terraform formatting, validation, and plan review | Terraform and TFLint |
| Ansible playbook development and linting | `pipx`, full Ansible, `ansible-lint`, and collections from `ansible/requirements.yml` |
| AWS Stage 0 bootstrap/deployment | AWS CLI, `session-manager-plugin`, Terraform, Ansible, `jq`, and S3-capable AWS credentials on the controller |
| Azure reference work | Azure CLI |
| Kubernetes or emulator labs | Only when used: Docker, `kubectl`, Helm, k3d, and the relevant emulator |

Install Ansible as an isolated operator tool rather than into a project or system Python environment:

```bash
pipx install --include-deps ansible
pipx install ansible-lint
ansible-galaxy collection install -r ansible/requirements.yml
```

The AWS Session Manager plugin is a native AWS package, not a PyPI dependency. It is required by the
`amazon.aws.aws_ssm` connection used by the Stage 0 Ansible playbooks. Keep AWS credentials in the
local credential store or short-lived federation; never put them in repository files. Pre-commit
hooks run most remaining checks in isolated environments.

Always select the cloud environment explicitly; this checkout currently defaults the Terraform recipe
to `aws-dev`. Before AWS initialization, create the versioned, encrypted, private S3 state
bucket. The backend uses S3-native lockfiles; DynamoDB locking is deprecated by Terraform. Then copy
`terraform/environments/aws-dev/backend.s3.hcl.example` to the ignored
`backend.s3.hcl` and fill it locally. Then use `TF_ENV=aws-dev just tf init` followed by
`TF_ENV=aws-dev just tf plan` for AWS Stage 0. Initialization configures the selected environment's
backend; it is non-mutating to cloud resources, while `plan` is still a required review gate before
any apply.

### Bootstrap the AWS State Backend

Run these AWS CLI commands once after choosing the account and `eu-central-1` region. They create
only the remote-state bucket; they do not provision the Stage 0 application infrastructure. The
account ID makes the globally unique bucket name deterministic for this account.

```bash
export AWS_REGION="eu-central-1"
export TF_STATE_BUCKET="api-observatory-tfstate-$(aws sts get-caller-identity --query Account --output text)"

aws s3api create-bucket \
  --bucket "${TF_STATE_BUCKET}" \
  --region "${AWS_REGION}" \
  --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
aws s3api put-bucket-versioning \
  --bucket "${TF_STATE_BUCKET}" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption \
  --bucket "${TF_STATE_BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Create the ignored backend file from the template and replace `ACCOUNT_ID` with the same account ID:

```bash
cp terraform/environments/aws-dev/backend.s3.hcl.example \
  terraform/environments/aws-dev/backend.s3.hcl
TF_ENV=aws-dev just tf init
TF_ENV=aws-dev just tf plan
```

`use_lockfile = true` causes Terraform to create and remove
`aws-dev/terraform.tfstate.tflock` automatically. It does not require a DynamoDB table.

Continue with the [deployment guide](docs/deployment/deployment-guide.md),
[platform observability](docs/operations/observability.md), or
[recovery guide](docs/operations/recovery-guide.md).
