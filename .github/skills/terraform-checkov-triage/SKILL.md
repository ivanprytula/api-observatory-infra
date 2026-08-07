---
name: terraform-checkov-triage
description: "Triage a Checkov finding against this repo's TERRAFORM_CHECKS.md deferral log. Determines whether a finding is a new deferral requiring justification and a fix timeline, or an existing tracked one that just needs its status confirmed. Cross-references the finding against baseline-checklist.md when it's security-relevant. USE FOR: Checkov CI failures, new Checkov findings, reviewing TERRAFORM_CHECKS.md entries."
metadata:
  applyTo: "terraform/**/*.tf, TERRAFORM_CHECKS.md"
argument-hint: "checkov-check-id (e.g. CKV_AWS_20)"
---

# Terraform Checkov Triage — Skill

Purpose: decide what to do with a Checkov finding without either silently suppressing it or blocking on
every low-value warning.

When to invoke: a `checkov` scan (local or CI) reports a new finding, or `TERRAFORM_CHECKS.md` needs a
status check during a plan-maintenance pass.

## Triage steps

1. **Identify the check ID** (for example, `CKV_AWS_20`) and read what it actually validates —
   don't triage from the summary line alone, pull the specific resource/attribute it's checking.
2. **Search `TERRAFORM_CHECKS.md`** for this check ID. If it's already there:
   - Confirm the resource address in the new finding matches an existing entry, or is a new instance of a
     previously-deferred pattern (e.g. same check, different environment).
   - Confirm the recorded fix timeline hasn't passed — if it has, this is not a routine confirmation
     anymore, flag it to the user as overdue.
3. **If it's not in `TERRAFORM_CHECKS.md`**, this is a new deferral decision, not an automatic pass:
   - First ask whether the check should just be *fixed* — most Checkov findings (missing encryption,
     missing versioning, open security group rules) have a low-cost fix. Default to fixing over deferring.
   - Only if fixing isn't feasible this cycle (e.g. blocked by free-tier SKU limitations, a dependency not
     yet migrated), add an entry to `TERRAFORM_CHECKS.md` with: check ID, resource, justification, and a
     concrete fix timeline — not "later."
4. **Cross-reference security relevance**: if the finding touches something in
   `docs/architecture/baseline-checklist.md` (the non-negotiable Security/SRE baseline), a deferral is not
   acceptable — baseline items must never regress per this repo's Plan Maintenance rules. Escalate to the
   user rather than deferring.

## What never gets deferred

- Anything overlapping the security baseline checklist.
- Findings on resources that hold PII, secrets, or session data (encryption-at-rest, public-access
  findings on storage).
- Findings where the "fix" is genuinely one line (e.g. adding a `tags` block, enabling versioning) — defer
  only real friction, not convenience.
