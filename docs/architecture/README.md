# Architecture

System design and infrastructure evolution reference for api-observatory-infra.

## Documents

| Doc | What it is |
|-----|------------|
| [evolution-plan.md](./evolution-plan.md) | **Living plan.** Greenfield rebuild blueprint + staged evolution (modulith-on-VM → microservices → K8s/GitOps) + trigger table + changelog. Start here. |
| [baseline-checklist.md](./baseline-checklist.md) | Non-negotiable Security/DevSecOps + SRE baseline. Copy when adding an environment or service. The 10 resolved issues that must never regress. |

## Related references

- [../app-repo-contract.md](../app-repo-contract.md) — container image contract with the app repo (UID, health endpoints, secrets, tagging).
- [../cloud-comparison.md](../cloud-comparison.md) — AWS vs Azure decision log.
- [../../TERRAFORM_CHECKS.md](../../TERRAFORM_CHECKS.md) — Checkov skip list with justifications + fix timelines.
- [../operations/](../operations/) — observability, webhooks, and the 5 runbooks.

## Current state

**Stage 0 — Modulith on VM (MVP).** See the evolution-plan [Status line](./evolution-plan.md) and
changelog for where the system actually is.
