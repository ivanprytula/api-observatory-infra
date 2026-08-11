# API Observatory — Infrastructure

AWS-first Infrastructure-as-Code for the [API Observatory](https://github.com/ivanprytula/api-observatory) platform.

AWS is the only active infrastructure direction. The [evolution plan](docs/architecture/evolution-plan.md) owns platform stages and
adoption triggers, while the [baseline](docs/architecture/baseline-checklist.md) owns durable
security/SRE controls.

For the whole product-to-platform story, start with the app-owned
[Application Lifecycle and SDLC](https://github.com/ivanprytula/api-observatory/blob/main/docs/01-intro/application-lifecycle.md).
It follows one vertical slice from idea and planning through development, delivery, operations,
maintenance, and transformation, with direct links back to this repository at each platform stage.
For the shared onboarding, task, PR, and release handoff checklist, use the app repository's
[Canonical Onboarding and Delivery Checklist](https://github.com/ivanprytula/api-observatory/blob/main/docs/05-development/onboarding-and-delivery-checklist.md).

## Working with the Repository

The [`Justfile`](Justfile) owns supported named workflows for diagnostics, Ansible linting, and
non-mutating AWS MVP scope help. Native Terraform and Ansible commands are
appropriate for explicit operator work. Follow [Contributing](CONTRIBUTING.md) for the task-branch and
pull-request lifecycle. Run `just help-aws-mvp` for the non-mutating operator sequence. Start with
static validation and a reviewed plan. Any apply, deployment, restore, chaos action, or teardown requires
explicit target review and approval.

## Runtime and Dependency Maintenance

`.python-version` selects the shared Python minor series (`3.14`) while `uv` resolves its current
compatible patch release. Dependabot opens weekly `uv` and GitHub Actions update PRs; review the
compatible group and each major upgrade while the change is small. When adopting a new Python minor,
change `.python-version` here and in the app repository in the same maintenance slice, then run
`uv lock --upgrade` and the relevant CI suites. Do not raise `requires-python` lower bounds unless
you are deliberately dropping support for an older runtime.

## Platform Boundaries and Contract

See [docs/overview.md](docs/overview.md) for the canonical app/platform boundary, platform contract, and prerequisites table.

### Bootstrap the AWS State Backend

Run these AWS CLI commands once after choosing the account and `eu-central-1` region. They create
only the remote-state bucket; they do not provision the MVP platform. The
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
cd terraform/environments/aws-dev
terraform init -reconfigure -upgrade -backend-config=backend.s3.hcl
terraform validate
terraform plan -input=false -var-file=terraform.tfvars -out=tfplan
terraform show tfplan
```

`use_lockfile = true` causes Terraform to create and remove
`aws-dev/terraform.tfstate.tflock` automatically. It does not require a DynamoDB table.

Continue with the [deployment guide](docs/deployment/deployment-guide.md),
[platform observability](docs/operations/observability.md), or
[recovery guide](docs/operations/recovery-guide.md). For the full boundary, contract, and evidence
model, see [docs/overview.md](docs/overview.md).
