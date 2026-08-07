---
name: terraform-plan-review
description: "Review an aws-dev Terraform plan before suggesting apply. Covers replacement/deletion, state drift, lifecycle guards, provider locking, cost, and the EC2 MVP contract."
metadata:
  applyTo: "terraform/**/*.tf, terraform/**/*.tfvars.example"
argument-hint: "environment: aws-dev"
---

# Terraform Plan Review — Skill

Purpose: catch destructive or risky changes in a `terraform plan` before they reach `apply`, and make sure
the user sees them clearly.

When to invoke: after running `terraform plan` (or `terraform plan -out=tfplan`) in
`terraform/environments/aws-dev`, before suggesting or running `apply`.

## Review checklist

- **Destructive actions**: scan plan output for `-/+ destroy and then create replacement` or bare
  `- destroy`. Any resource replacement or deletion must be called out explicitly to the user with the
  resource address and *why* Terraform wants to replace it (usually an immutable attribute change).
- **Lifecycle guards**: for stateful resources (S3 buckets and EBS volumes),
  confirm `lifecycle { prevent_destroy = true }` is present or the destroy is genuinely intended.
  `create_before_destroy` matters for anything with a dependent resource (e.g. security groups referenced
  elsewhere). `ignore_changes` should be scoped to specific attributes, never a blanket `all`.
- **Provider pinning**: check `required_providers` blocks pin an exact or narrowly-constrained version
  (`~> 6.52`, not unpinned). An unpinned provider means a plan today can differ from a plan tomorrow with no
  code change.
- **MVP contract**: verify the plan remains one private SSM-operated EC2 Compose host with encrypted
  EBS, ECR, Parameter Store, retained S3 backups, and no inbound SSH or public app ingress.
- **Backend/state**: never read `.tfstate*` files directly to answer "what changed" — the plan output is the
  source of truth. If state inspection is genuinely needed, use `terraform show` output, not raw state JSON.

## Output format

Summarize as: resources to add / change in place / destroy / replace, counts first, then call out each
destroy or replace by name with the reason. End with a explicit go/no-go recommendation — never assume
silence means approval to `apply`.
