# Architecture

System design and infrastructure evolution reference for api-observatory-infra.

## Documents

| Doc | What it is |
|-----|------------|
| [evolution-plan.md](./evolution-plan.md) | **Living plan.** Greenfield rebuild blueprint + staged evolution (modulith-on-VM → microservices → K8s/GitOps) + trigger table + changelog. Start here. |
| [baseline-checklist.md](./baseline-checklist.md) | Non-negotiable Security/DevSecOps + SRE baseline. Copy when adding an environment or service. The 10 resolved issues that must never regress. |

## Related references

- [App repository contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md) — canonical image, port, health, environment, and secret-delivery boundary.
- [../cloud-comparison.md](../cloud-comparison.md) — AWS vs Azure decision log.
- [../../TERRAFORM_CHECKS.md](../../TERRAFORM_CHECKS.md) — Checkov skip list with justifications + fix timelines.
- [../operations/](../operations/) — observability, webhooks, and the 5 runbooks.

## Current state

**Stage 0 — Modulith on VM (MVP).** See the evolution-plan [Status line](./evolution-plan.md) and
changelog for where the system actually is.
