---
name: terraform-plan-review
description: "Review a `terraform plan` output before suggesting `apply`. Covers destructive changes (resource replacement/deletion), state drift, missing `lifecycle` blocks (`prevent_destroy`, `create_before_destroy`, `ignore_changes`), unpinned or loosely pinned provider versions, and cross-environment parity checks between azure-sandbox/azure-dev and aws-sandbox/aws-dev. Includes a checklist for what must be surfaced to the user before any apply."
metadata:
  applyTo: "terraform/**/*.tf, terraform/**/*.tfvars.example"
argument-hint: "environment: azure-sandbox|azure-dev|aws-sandbox|aws-dev"
---

# Terraform Plan Review — Skill

Purpose: catch destructive or risky changes in a `terraform plan` before they reach `apply`, and make sure
the user sees them clearly.

When to invoke: after running `terraform plan` (or `terraform plan -out=tfplan`) in any
`terraform/environments/<env>/` directory, before suggesting or running `apply`.

## Review checklist

- **Destructive actions**: scan plan output for `-/+ destroy and then create replacement` or bare
  `- destroy`. Any resource replacement or deletion must be called out explicitly to the user with the
  resource address and *why* Terraform wants to replace it (usually an immutable attribute change).
- **Lifecycle guards**: for stateful resources (databases, storage accounts/buckets, persistent volumes),
  confirm `lifecycle { prevent_destroy = true }` is present or the destroy is genuinely intended.
  `create_before_destroy` matters for anything with a dependent resource (e.g. security groups referenced
  elsewhere). `ignore_changes` should be scoped to specific attributes, never a blanket `all`.
- **Provider pinning**: check `required_providers` blocks pin an exact or narrowly-constrained version
  (`~> 5.x`, not unpinned). An unpinned provider means a plan today can differ from a plan tomorrow with no
  code change.
- **Cross-cloud parity**: per this repo's convention (`CLAUDE.md` — "Keep AWS and Azure environments
  structurally parallel"), if a variable or resource pattern changes in `azure-*`, check whether the
  equivalent `aws-*` environment needs the same change.
- **Backend/state**: never read `.tfstate*` files directly to answer "what changed" — the plan output is the
  source of truth. If state inspection is genuinely needed, use `terraform show` output, not raw state JSON.

## Output format

Summarize as: resources to add / change in place / destroy / replace, counts first, then call out each
destroy or replace by name with the reason. End with a explicit go/no-go recommendation — never assume
silence means approval to `apply`.
