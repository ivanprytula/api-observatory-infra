# Baked-in Baseline Checklist

The non-negotiable Security/DevSecOps + SRE baseline for **every** environment and service.
Each item below was a real issue resolved during the initial build — they are baked in here so
they **never regress**. Copy this checklist when standing up a new environment or extracting a
new service; CI Checkov + the documented skip list in [TERRAFORM_CHECKS.md](../../TERRAFORM_CHECKS.md)
keep it enforced.

> **Rule:** an environment/service is not "done" until every **Security** item passes, and not
> "production-ready" until every **SRE** item exists.
>
> **YAGNI does not apply here.** These items are table stakes, not speculative gold-plating
> (principle P2 in [evolution-plan.md](./evolution-plan.md)). "Boring/business-first" governs
> *feature scope and architecture stages* — never the security/SRE baseline below.

---

## Security (must pass before an environment is "done")

Each row maps to a concrete control. Where a Checkov ID is listed, that check must be **passing**
(not in the skip list). Terraform patterns reference the relevel files as the source of truth.

| # | MUST | Enforced by | Reference |
|---|------|-------------|-----------|
| 1 | IMDSv2 only (`http_tokens=required`) | Terraform + Checkov | `terraform/environments/aws-dev/main.tf` (metadata_options) |
| 2 | Encryption at rest — storage, RDS, EBS, logs via **KMS CMK + rotation** | Checkov (encryption family) | aws-dev KMS key + `storage_encrypted`; azure-dev storage encryption |
| 3 | Encryption in transit — TLS 1.2+ floor | Terraform | Azure storage `min_tls_version`; RDS SSL enforced |
| 4 | Private DB only — no public endpoint | Checkov | RDS `publicly_accessible=false`; Azure PG VNet-integrated private DNS |
| 5 | No public storage (no `0.0.0.0/0` to buckets/accounts) | Checkov | Azure storage public access disabled |
| 6 | Egress restricted to TCP 80/443/5432 (no allow-all) | Terraform SG/NSG rules | aws-dev SG egress; azure-dev NSG outbound |
| 7 | Ingress scoped to `var.admin_cidr` for HTTP/SSH; only HTTPS open to `0.0.0.0/0` | Terraform | aws-dev SG ingress; azure-dev NSG inbound |
| 8 | SG/NSG rules carry **explicit descriptions** | Checkov | all SG/NSG rule blocks |
| 9 | IAM/AAD auth + least-privilege roles (scoped ARNs, no wildcards) | Checkov | RDS IAM auth; flow-logs role scoped to log-group ARN |
| 10 | VPC Flow Logs + query logging, **KMS-encrypted** | Terraform (enable when budget allows — see skip table) | aws-dev flow logs; **CKV2_AWS_11/30 currently deferred** |
| 11 | Deletion protection + final snapshot + geo/redundant backup | Terraform | RDS deletion protection + final snapshot; Azure geo-backup |
| 12 | No hardcoded secrets — Ansible Vault + `detect-private-key` hook | pre-commit + `.claude/settings.json` deny rules | `.pre-commit-config.yaml`; vault.yml never read |
| 13 | Pinned provider versions; parallel AWS/Azure variable names | Terraform convention | provider blocks in each env |
| 14 | No `aws_default_security_group` resource (AWS manages implicitly) | convention (CKV2_AWS_12 documented skip) | removed in commit `fc4d54b` |

### K8s-specific security (applies in Stage 3+; designed now, kept warm)

| # | MUST | Reference |
|---|------|-----------|
| K1 | Containers run as non-root **UID 10001**, read-only root FS, drop ALL caps | [app-repo-contract.md](../app-repo-contract.md); all deployment manifests |
| K2 | `seccompProfile: RuntimeDefault` + `allowPrivilegeEscalation: false` | deployment securityContext blocks |
| K3 | Network policies mandatory; **DNS egress restricted to kube-dns** (not global) | `kubernetes/manifests/network-policies/06-*`, `07-*` |
| K4 | Namespace injected by Kustomize (manifests namespace-agnostic) | `kubernetes/overlays/local/kustomization.yaml` |
| K5 | `imagePullPolicy: IfNotPresent` for `:latest` dev; `Always` + **digest pinning** for prod CI | manifests vs prod overlay |
| K6 | Secrets via external store (ESO / Key Vault CSI / Secrets Manager CSI), not plain Secret objects | Stage 3 prerequisite |
| K7 | `automountServiceAccountToken: false` unless explicitly needed | all deployment manifests |

---

## SRE (must exist before production traffic)

| # | MUST | Reference |
|---|------|-----------|
| 1 | SLOs + error budgets defined and dashboarded | `monitoring/grafana/dashboards/slo-dashboard.json` |
| 2 | Prometheus scraping **every** service (`/metrics`) | `monitoring/prometheus.yml` |
| 3 | Alertmanager routes for critical + warning, with inhibition | `monitoring/alertmanager.yml` |
| 4 | Log aggregation (Loki + Promtail) | `monitoring/promtail.yml` |
| 5 | Runbooks for the 5 core scenarios | `docs/operations/runbooks/` (backup-restore, chaos, circuit-breaker, dlq-replay, slo-breach) |
| 6 | Backup **and restore** drill validated (not just backup) | `scripts/backup.sh` + `scripts/restore.sh` |
| 7 | Chaos scenarios runnable | `scripts/chaos.sh` (kill / network / db / kafka / memory / gauntlet) |
| 8 | Resource requests + limits on every workload | deployment manifests |

---

## The 10 resolved issue categories (never-regress list)

These are the categories of low/mid/high issues found and fixed during the build. Any change
that reintroduces one of these is a regression:

1. **Instance metadata (IMDSv1 → IMDSv2)** — SSRF exposure.
2. **Unencrypted data at rest/transit** — KMS CMK + TLS 1.2 floor.
3. **Overly permissive ingress** — `admin_cidr` scoping, HTTPS-only public.
4. **Missing egress controls** — restricted to 80/443/5432.
5. **Insufficient logging/monitoring** — Flow Logs, RDS monitoring, enhanced metrics.
6. **No deletion protection / backup gaps** — protection + final snapshot + geo-backup.
7. **IAM over-permissions** — wildcard → scoped ARNs.
8. **Weak transport security** — TLS 1.0/1.1 → 1.2 minimum.
9. **Checkov compliance gaps** — SG descriptions, RDS IAM auth, performance insights.
10. **K8s hygiene** — hardcoded namespaces, wrong `imagePullPolicy`, unrestricted DNS egress.

---

## OWASP coverage (evolving threat mapping)

OWASP lists change on multi-year cycles (Top 10: 2017 → 2021 → 2025). We **don't** chase every
revision or adopt a new scanner per category — instead we map each OWASP category to a control we
**already own**, make coverage visible, and re-check yearly. New tooling is added only when a
mapping has a real gap (a justified P1/P2 exception, filed as a ticket).

**Lists that apply (and when):**

- **OWASP API Security Top 10** — primary; we are API-first (ingestor/webhook).
- **OWASP Top 10 (web)** — primary; FastAPI services + Streamlit dashboard.
- **OWASP Top 10 CI/CD Security Risks** — becomes primary at Stage 3+ (GitOps/supply-chain).
- **Kubernetes / Cloud-Native lists** — deferred until Stage 3 (consistent with the staged plan).

**Category → control mapping** (current as of the date below; update each yearly review):

| OWASP theme | Owned by | Status |
|-------------|----------|--------|
| IaC misconfiguration (broken access control, misconfig) | Checkov (CI + pre-commit) | ✅ active |
| Secrets exposure / cryptographic failures | `detect-private-key`, `.claude/settings.json` deny rules, Ansible Vault, KMS/TLS baseline items 2–3, 12 | ✅ active |
| Vulnerable & outdated components | Dependabot (`.github/dependabot.yml`) | ✅ active |
| Security misconfiguration (network/IAM) | baseline items 4–11 (egress, ingress, IAM, logging) | ✅ active |
| Injection / insecure design (app code) | App-repo responsibility; **gap at infra layer** → candidate: Semgrep/Bandit SAST when app code lands in scope | ⚠ gap — ticket if needed |
| Vulnerable container images | **gap** → candidate: Trivy image scan in CI at Stage 2+ (first per-service image) | ⚠ gap — Stage 2 trigger |
| CI/CD pipeline integrity (poisoned pipeline, unsigned artifacts) | partial; full coverage = Stage 4 (cosign/SBOM/admission policy) | ◑ staged |

> Gaps are **acknowledged, not silently accepted** — each has a trigger (stage or ticket). Adding
> Semgrep/Trivy/cosign is a justified tooling addition (P1/P2), not preemptive overengineering.

**Yearly OWASP review (cadence):** every **June** (anchored to this doc's creation), re-read the
current OWASP API + Web Top 10, update the table above, and file any new gap as a ticket. This
review is a trigger in [evolution-plan.md](./evolution-plan.md) → "How to extend".

> The OWASP mapping **extends** the never-regress list above — it never replaces it.

---

**Last updated**: 2026-06-28 · Maintained per [evolution-plan.md](./evolution-plan.md) → "How to extend".
