# Terraform Security Checks — MVP Justifications

This document explains which Checkov security checks are skipped in `.pre-commit-config.yaml` for Terraform and why.

## Skipped Checks (MVP Free Tier Constraints + Architecture)

| Check ID | Rule | MVP Justification | Fix Timeline |
|----------|------|-------------------|--------------|
| CKV2_AWS_12 | Default SG restricts all traffic | Removed explicit default_security_group resource; AWS manages implicitly (deny-all by default) | N/A (implicit) |
| CKV2_AWS_5 | SGs attached to resources | Sandbox app-sg not used in dev (only in sandbox TF state); no resources using it yet | Post-MVP (when scaling) |
| CKV2_AWS_41 | IAM role attached to EC2 | MVP uses SSH key-pair auth; IAM role for SSM/monitoring deferred | Post-MVP (SSM setup) |
| CKV_AWS_130 | Disable public IP auto-assign | Public subnets needed for NAT/ingress; mitigated by restrictive SGs | Post-MVP (private-only) |
| CKV_AWS_157 | Enable Multi-AZ for RDS | Free tier constraint (750 hrs/mo) — single-AZ only; ok for dev | Post-MVP (HA) |
| CKV2_AWS_11 | Enable VPC Flow Logs | CloudWatch cost (~$0.50/GB); defer for MVP | Post-MVP (monitoring) |
| CKV2_AWS_30 | Enable RDS Query Logging | CloudWatch cost; defer for MVP | Post-MVP (audit) |
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

- ✅ Encryption (KMS keys, TLS, storage encryption)
- ✅ Network security (SG/NSG ingress/egress rules)
- ✅ Public access restrictions (no open DB/storage to 0.0.0.0/0)
- ✅ Terraform formatting and validation
- ✅ No hardcoded secrets

## K8s Checks (Skipped in MVP)

The following checks are skipped because K8s deployment is **not in MVP scope**:

- CKV_K8S_14, 15, 21, 35, 43 — skipped (namespace injection, image tags, secrets patterns)
- CKV_SECRET_4, 6 — skipped (secret detection)

When migrating to K8s (post-MVP), re-enable and document as architectural decisions in a separate K8s security policy.

## Scope

- **Applies to**: `terraform/environments/aws-dev`, `terraform/environments/aws-sandbox`, `terraform/environments/azure-dev`
- **Deployment target**: AWS EC2 / Azure VMs (not K8s in MVP)
- **K8s manifests**: Kept as future reference, not scanned in MVP

## Review Cadence

Re-evaluate these skips:

- Budget allows CloudWatch costs → enable Flow Logs + Query Logging
- Migrate to production (post-MVP) → enable Multi-AZ, CMK, private endpoints
- Free tier expires → baseline hardening required for paid tiers

---

**Last updated**: 2026-06-28
