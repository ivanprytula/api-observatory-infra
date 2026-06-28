# Infrastructure Evolution Plan — Modulith → Microservices → K8s

> **Status:** Stage 0 (Modulith on VM, MVP) · **Last advanced:** 2026-06-28
> **Living document** — extend it, don't rewrite it. See [How to extend](#how-to-extend-this-plan).

## Why this document exists

`api-observatory-infra` is the multi-cloud IaC repo (Terraform AWS+Azure, Ansible, K8s/Helm,
monitoring) for [api-observatory](https://github.com/ivanprytula/api-observatory). During the
initial build ~30 security/quality issues were found and fixed iteratively. This document:

1. Lets the infra be **rebuilt from scratch with zero recurrence** of those issues — they are a
   baked-in baseline (see [baseline-checklist.md](./baseline-checklist.md)), not findings to
   rediscover.
2. Is the **living reference** for the staged, evidence-driven path from modulith-on-VM →
   microservices → full K8s/GitOps.

**Stance:** Staged and evidence-driven. Stay modulith-on-VM until concrete signals justify each
step. **Depth:** Architecture and Delivery/GitOps are deep; Security/SRE are a baked-in baseline
checklist, not prose.

Two axes evolve **independently**: *architectural decomposition* (modulith → services) and
*platform migration* (VM → K8s). Don't conflate them — you can have a clean modulith on K8s, or
two services on a VM.

---

## Part A — Greenfield Blueprint (rebuild issue-free)

Build in this order so each layer lands already-hardened. Every step satisfies a
[baseline-checklist](./baseline-checklist.md) item — nothing is "fixed later."

### A1 — Repo & guardrails first (before any cloud resource)
Scaffold `terraform/environments/{aws-dev,aws-sandbox,azure-dev,azure-sandbox}`, `ansible/`,
`kubernetes/`, `monitoring/`, `scripts/`, `docs/`. Land guardrails up front so no bad commit is
possible:
- `.pre-commit-config.yaml` (terraform fmt/validate/tflint, checkov, yamllint, shellcheck,
  ansible-lint), `.tflint.hcl`, `.yamllint.yml`, `.editorconfig`.
- `.claude/settings.json` (deny secret reads + destructive ops), `SECURITY.md`.
- `.github/workflows/ci.yml`.
- `TERRAFORM_CHECKS.md` seeded with the documented skip list → Checkov green from commit #1 with
  *justified* skips only.

### A2 — Terraform baseline modules (hardened by construction)
Each cloud env passes Checkov minus the documented skips. Reference patterns:
`terraform/environments/aws-dev/main.tf`, `terraform/environments/azure-dev/main.tf`.
Bake in from the start: **Compute** (IMDSv2, volume encryption, detailed monitoring); **Data**
(private DB, KMS CMK + rotation, IAM/AAD auth, deletion protection, final snapshot, geo-backup);
**Network** (SG/NSG with descriptions, egress 80/443/5432, ingress scoped to `admin_cidr`,
subnet-level NSG association); **Logging** (Flow Logs + CloudWatch, KMS-encrypted, enhanced
monitoring, boot diagnostics); **Hygiene** (pinned providers, parallel var names, no
`aws_default_security_group`). → checklist items 1–14.

### A3 — Config layer (Ansible), modulith on VM
Roles `common`, `docker`, `app`, `monitoring`, `secrets`. Provision playbooks delegate to roles
(no inline tasks). Secrets via Ansible Vault, never plaintext/echoed. `roles_path` repo-relative;
run playbooks from repo root.

### A4 — Deploy layer: Docker Compose modulith (the MVP target)
Single VM runs the modulith via Compose. App images follow the
[container contract](../app-repo-contract.md): UID 10001, `/health` + `/readyz`, non-root,
read-only FS, secrets via env, `tree-<SHA>` tags.

### A5 — Observability from day one
Prometheus scrape configs, Alertmanager routes, Loki/Promtail, Grafana dashboards + SLO dashboard.
Baseline, not post-MVP. → SRE checklist items 1–4.

### A6 — K8s artifacts kept warm (not the active path)
`kubernetes/manifests/` namespace-agnostic (Kustomize injects namespace); network policies
mandatory with DNS egress restricted to kube-dns; `imagePullPolicy: IfNotPresent` for `:latest`
dev, `Always` + digest for prod CI; Helm charts lint-clean. Ready for Stage 3 without being
deployed. → checklist items K1–K7.

---

## Part B — Staged Evolution

Each stage has **entry triggers** (don't advance early) and a **migration path**.

### Stage 0 — Modulith on VM (current MVP)
One deployable, Docker Compose, single VM per cloud. Redpanda/Redis/Postgres managed or co-located.
**Exit triggers →** deploy friction (>1 risky deploy/week) · a module needing independent scaling ·
a second team/owner · sustained CPU/mem pressure on the VM.

### Stage 1 — Modular monolith with seams (still one deployable)
Enforce internal module boundaries (clear interfaces, owned data, no cross-module DB reads).
Introduce the eventing seam (Redpanda topics) where async fits. Mostly *app-repo* work; infra adds
topic/stream provisioning + per-module dashboards. **Why first:** microservices extracted from
clean seams succeed; from a big ball of mud they fail. De-risk before paying distributed-systems
cost.

### Stage 2 — First service extraction (hybrid: VM + 1–2 services)
Extract the highest-value, independently-scaling module — likely `inference` (heavy, bursty). May
still run on VM/Compose or a managed container runtime (ECS / Container Apps) before committing to
K8s. Infra: per-service CI image, per-service contract entry, service-to-service auth (internal
JWT already in manifests), network egress rules. **Exit triggers →** 3+ services · need for
self-healing/bin-packing · polyglot runtimes.

### Stage 3 — Orchestrated microservices on K8s (AKS/EKS)
Activate the warm K8s artifacts. Kustomize overlays per env (`dev`/`prod` × `aws`/`azure`).
Mandatory network policies, HPA, PodDisruptionBudgets, resource requests/limits.
**Platform-migration prerequisites (baseline gates):** namespace strategy · secrets via external
store (ESO / Key Vault CSI / Secrets Manager CSI) · image digest pinning + `imagePullPolicy:
Always` · restricted DNS egress — all designed in [A6](#a6--k8s-artifacts-kept-warm-not-the-active-path).
**Exit triggers →** multiple clusters/regions · declarative drift control · release-velocity pain.

### Stage 4 — GitOps + progressive delivery
- **GitOps:** Argo CD or Flux as single source of truth; cluster state = git state. Repo layout
  `clusters/<env>/` app-of-apps; Kustomize/Helm references; image updater on `tree-<SHA>`.
- **Promotion:** `dev → staging → prod` via PR-based promotion (env-folder or env-branch). No
  human `kubectl apply`.
- **Progressive delivery:** Argo Rollouts / Flagger — canary or blue-green keyed on existing
  SLO/Prometheus metrics; auto-rollback on error-budget burn.
- **Supply chain:** signed images (cosign), SBOM, admission policy (Kyverno/OPA) enforcing the
  container contract at the cluster.

### Stage 5 — Scale & resilience hardening (high-load)
Multi-AZ/region, read replicas, autoscaling (HPA+VPA / cluster autoscaler), cache tiering,
partition-aware consumers (the `processor` single-consumer constraint is already annotated).
Re-enable cost-deferred Checkov items (Multi-AZ RDS, flow-log retention, CMK storage) per the
[skip table](../../TERRAFORM_CHECKS.md) timelines.

### Trigger summary

| Signal | From → To | Primary owner |
|--------|-----------|---------------|
| Deploy friction / independent scaling | Stage 0 → 1 | App + Infra |
| Clean module seams + eventing in place | Stage 1 → 2 | App |
| 3+ services / self-healing needed | Stage 2 → 3 | Infra |
| Multiple clusters / release-velocity pain | Stage 3 → 4 | Infra/Platform |
| High-load / multi-region SLOs | Stage 4 → 5 | SRE |

---

## Part C — Baked-in baseline (summary)

Security and SRE are enforced as a checklist, not prose. Full list:
[baseline-checklist.md](./baseline-checklist.md). An environment is not "done" until every Security
item passes; not "production-ready" until every SRE item exists. The 10 resolved issue categories
form a never-regress list.

---

## How to extend this plan

When the system changes, update this doc in the same PR. Triggers:

- **Adding a service** → update [app-repo-contract.md](../app-repo-contract.md), add a per-service
  observability target (Prometheus job + dashboard), and re-check the [trigger summary](#trigger-summary).
- **Adding an environment** → apply the **full** [baseline-checklist](./baseline-checklist.md);
  every new Checkov skip must land in [TERRAFORM_CHECKS.md](../../TERRAFORM_CHECKS.md) with a fix
  timeline.
- **Advancing a stage** → add a row to the [changelog](#changelog) with the triggering signal and
  bump the **Status** line at the top.
- **Deferring a Checkov check** → it must appear in `TERRAFORM_CHECKS.md` with justification + fix
  timeline, and (if security-relevant) be noted against the matching baseline item.

Append, don't rewrite. Keep the changelog honest about where the system actually is.

### Changelog

| Date | Change | Stage | Trigger / reason |
|------|--------|-------|------------------|
| 2026-06-28 | Plan created; baseline + maintenance hooks established | Stage 0 | MVP modulith-on-VM; baking in resolved-issue baseline |
