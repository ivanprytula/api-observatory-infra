# Terraform Security Checks — MVP Justifications

This document explains which Checkov security checks are skipped in `.pre-commit-config.yaml` for Terraform and why.

## Skipped Checks (MVP Free Tier Constraints + Architecture)

| Check ID | Rule | MVP Justification | Fix Timeline |
| ---------- | ------ | ------------------- | -------------- |
| CKV2_AWS_12 | Default SG restricts all traffic | Removed explicit default_security_group resource; AWS manages implicitly (deny-all by default) | N/A (implicit) |
| CKV2_AWS_5 | SGs attached to resources | Sandbox app-sg not used in dev (only in sandbox TF state); no resources using it yet | Post-MVP (when scaling) |
| CKV_AWS_130 | Disable public IP auto-assign | Stage 0 currently uses a public subnet for low-cost outbound access, but has no inbound rules and is operated through SSM | Move to private subnets/VPC endpoints before public or shared use |
| CKV2_AWS_11 | Enable VPC Flow Logs | `aws-dev` enables flow logs; the LocalStack-only `aws-sandbox` omits paid CloudWatch plumbing | Add sandbox logging if it becomes a live or shared environment |
| CKV2_AWS_62 | Enable S3 event notifications | Stage 0 backup and one-day Ansible transfer buckets have no event-driven consumer | Add notifications with a concrete audit or automation consumer |
| CKV_AWS_18 | Enable S3 access logging | Stage 0 avoids a recursive logging-bucket surface; CloudTrail data events are not yet in scope | Before public or shared use |
| CKV_AWS_21 | Enable S3 versioning | Backups are versioned; the one-day Ansible transfer bucket is intentionally ephemeral and unversioned | Revisit if transfer artifacts gain recovery value |
| CKV_AWS_136 | Encrypt ECR with a customer-managed KMS key | ECR uses AWS-managed AES-256 encryption; a customer key adds grants, policy, and cost without a Stage 0 compliance requirement | Before regulated or shared use |
| CKV_AWS_144 | Enable S3 cross-region replication | Single-region Stage 0 accepts regional loss and keeps restore evidence local to the target | Add after a measured cross-region recovery requirement |
| CKV_AWS_145 | Encrypt S3 with a customer-managed KMS key | Both Stage 0 buckets use server-side AES-256 encryption; customer-key permissions would expand bootstrap and restore coupling | Before regulated or shared use |
| CKV_AZURE_50 | No VM Extensions | Needed for monitoring agents in dev; mitigated by NSG rules | Post-MVP (managed) |
| CKV_AZURE_43 | Storage naming convention | Current names valid; low-risk | N/A |
| CKV_AZURE_119 | NIC without public IP | Need public IP for SSH access; restricted by NSG | Post-MVP (Bastion) |
| CKV2_AZURE_1 | CMK encryption for storage | Free tier uses default encryption; CMK adds complexity | Post-MVP (compliance) |
| CKV2_AZURE_21 | Storage logging (Blob) | Additional cost; defer for MVP | Post-MVP (audit) |
| CKV2_AZURE_31 | Subnet NSG association | PostgreSQL subnet uses network restriction via DB firewall | Post-MVP (NSG hardening) |
| CKV2_AZURE_33 | Private endpoint for storage | Free tier; acceptable for dev environment | Post-MVP (network isolation) |
| CKV2_AZURE_40 | Disable Shared Key auth | Requires SAS tokens; deferred for MVP simplicity | Post-MVP (RBAC) |
| CKV2_AZURE_41 | SAS expiration policy | MVP uses connection strings; defer policy | Post-MVP (token mgmt) |
| CKV2_AZURE_57 | Private endpoint for DB | Free tier; acceptable for dev environment | Post-MVP (network isolation) |
| CKV_AZURE_206 | Storage replication | Free tier default (LRS); upgrade to GRS in prod | Post-MVP (durability) |

## Critical Checks NOT Skipped

These checks are **actively enforced**:

- ✅ Encryption at rest (provider-managed or customer-managed as documented), TLS, and storage encryption
- ✅ Network security (SG/NSG ingress/egress rules)
- ✅ Public access restrictions (no open DB/storage to 0.0.0.0/0)
- ✅ Terraform formatting and validation
- ✅ No hardcoded secrets

## Kubernetes Scan Scope

The required Checkov gate scans `terraform/` only. Kubernetes examples are secondary/reference evidence
and have separate Helm and YAML validation; they are not silently included in the Terraform policy gate.
Add a dedicated Kubernetes security policy and Checkov job when Kubernetes becomes a deployment target.

## Scope

- **Applies to**: all four directories under `terraform/environments/`
- **Deployment target**: AWS EC2 / Azure VMs (not K8s in MVP)
- **K8s manifests**: Kept as future reference, not scanned in MVP

## Tracked Decisions (not Checkov skips — deliberate choices with a revisit trigger)

| Decision | Current choice | Rationale | Revisit when |
| ---------- | --------------- | ----------- | -------------- |
| Provider lockfile (`.terraform.lock.hcl`) | **Gitignored** (`.gitignore:6`) — not committed | Single-maintainer MVP: no lock-diff noise in PRs, CI re-resolves latest-matching on each `init -backend=false`. Trade-off: **not reproducible** — two applies days apart may use different provider patch versions, weakening the baseline's "pinned provider versions" guarantee. | **Stage 3** (K8s / multi-machine / production `apply`). Commit the lock (Terraform's official recommendation) for reproducible, auditable builds and proper Dependabot lock bumps. See [evolution-plan.md](docs/architecture/evolution-plan.md). |
| Branch strategy | **Single-branch (`main` only)** | MVP: one maintainer, four low-risk environments (dev/sandbox × AWS/Azure). All code changes flow through `main` → all envs via `.tfvars` isolation. Risk: a bug in sandbox config could affect dev if `.tfvars` separation is not carefully maintained. No need for environment-branches yet; coordination overhead would exceed benefit. | **Stage 2** (multi-service, concurrent changes to different environments, or a second maintainer). If you see merge-coordination friction or want an audit trail (deploy-history = git-history), switch to environment-branches: `prod/aws`, `prod/azure`, optional `staging/*`. Branches would be rebase-only from `main` (fast-forward only), protecting prod from accidental config drift. |

## Review Cadence

Re-evaluate these skips:

- Budget allows CloudWatch costs → enable Flow Logs + Query Logging
- Migrate to production (post-MVP) → enable Multi-AZ, CMK, private endpoints
- Free tier expires → baseline hardening required for paid tiers
- **Stage 3 (multi-machine / production apply) → commit `.terraform.lock.hcl`** (see Tracked Decisions)

> **Provider-major reminder:** after any AWS/Azure provider major bump (e.g. AWS v5→v6, applied 2026-06-29), run `terraform plan` and eyeball the diff for unexpected resource replacements **before** `apply`. `terraform validate` (what CI runs) confirms schema validity but not plan-time diffs against real cloud state.

---

**Last updated**: 2026-06-29
