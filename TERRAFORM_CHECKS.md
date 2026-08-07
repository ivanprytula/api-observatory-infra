# Terraform Security Checks — AWS MVP Justifications

This document records the narrow Checkov exceptions for the sole active Terraform environment,
`terraform/environments/aws-dev`. Static validation is not evidence of an applied control.

## Skipped Checks

| Check ID | MVP justification | Revisit when |
| --- | --- | --- |
| `CKV_AWS_130` | The private, SSM-operated MVP host uses a public subnet only for low-cost outbound access and has no inbound rules | Before public or shared use; prefer private subnets and VPC endpoints |
| `CKV2_AWS_62` | Backup and one-day Ansible transfer buckets have no event-driven consumer | A concrete audit or automation consumer exists |
| `CKV_AWS_21` | Backups are versioned; the one-day transfer bucket is intentionally ephemeral | Transfer artifacts gain recovery value |
| `CKV_AWS_144` | The single-region MVP explicitly accepts regional loss | A cross-region recovery objective is approved |
| `CKV_AWS_136` | ECR uses AWS-managed encryption; a customer key has no current compliance requirement | Regulated or shared use requires customer-managed keys |
| `CKV_AWS_145` | S3 uses server-side AWS-managed encryption; customer-key grants would expand MVP coupling | Regulated or shared use requires customer-managed keys |

The skip list must remain identical in `.pre-commit-config.yaml` and `.github/workflows/ci.yml`.
New findings are fixed by default; any new exception requires a concrete resource, justification,
and revisit condition here.

## Enforced Baseline

- IMDSv2, encrypted EBS, encrypted storage, bounded networking, and resource-scoped IAM remain
  enforced in `aws-dev`.
- Real variable values, backend configuration, state, credentials, and runtime secrets stay outside
  Git.
- The committed AWS provider lock is the reproducible dependency source for this environment.
- Terraform format/validate, TFLint, Checkov, and plan review are required before any apply.

## Evidence Boundary

The repository has one Terraform environment and one deployment target: AWS EC2 Compose. ECS on
Fargate and EKS are later learning stages, not current Terraform surfaces. Another IaaS provider is
ineligible until EC2, ECS-on-Fargate, and EKS exercises have retained evidence.
