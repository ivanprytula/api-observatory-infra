# Infrastructure Evolution — VM to Managed Platform

> **Status:** AWS Stage 0 is a planned, statically validated direction; no live deployment is
> claimed.

The app contract defines three HTTP images—ingestor, inference, and dashboard—co-located on one EC2
Docker Compose platform with RDS. AWS is the primary portfolio direction. Azure assets remain
secondary/reference material; local cloud emulators remain app-owned labs.

## Principles

- Prefer the simplest platform that meets the current product, reliability, and recovery need.
- Keep application boundaries independent from platform choice: Kubernetes does not create clean
  service ownership, and clean services do not require Kubernetes.
- Treat the [security/SRE baseline](baseline-checklist.md) as a floor, not speculative scope.
- Advance from measured delivery, scaling, availability, recovery, or ownership pressure—not from
  technology interest.
- Describe Terraform, manifests, plans, and local labs as configuration evidence until exercised.

## Current Contract

| Concern | Current direction |
| --- | --- |
| Compute | One EC2 host running the three application images with Docker Compose |
| Database | RDS PostgreSQL; inference retains its app-defined data ownership boundary |
| Registry | Private ECR images tagged `tree-<SHA>` |
| Identity | Short-lived GitHub OIDC roles and EC2 instance role; prerequisite, not yet provisioned here |
| Delivery | App-owned protected workflow through Systems Manager |
| Monitoring | Prometheus/Alertmanager/Grafana/Promtail assets; live backends and evidence still required |
| Secondary cloud | Azure Terraform/Ansible retained for comparison, not the primary deployment claim |

The app-owned [deployment contract](https://github.com/ivanprytula/api-observatory/blob/main/docs/07-deployment/app-repo-contract.md)
is authoritative for images, ports, health, environment names, and secret-consumption behavior.

## Evolution Stages

| Stage | Platform shape | Entry evidence |
| --- | --- | --- |
| 0 | Three images on one EC2 Compose host | Approved cost/security plan plus local image/contract proof |
| 1 | Same platform with strengthened service/module seams | Contract or ownership friction on the shared runtime |
| 2 | First independently operated workload, likely inference | Independent scale, release cadence, or isolation objective |
| 3 | Kubernetes orchestration | Several workloads need self-healing, scheduling, or consistent platform policy |
| 4 | GitOps/progressive delivery | Multiple environments/clusters create drift or release-risk evidence |
| 5 | Multi-AZ/region and advanced scaling | Explicit SLO/RTO/RPO or sustained capacity evidence |

## Transformation Gates

- Multiple ingestor replicas require a stateless request path and explicit scheduler ownership.
- A managed gateway requires multiple public services or consumer-specific edge policy.
- ECS/Kubernetes requires repeated Compose delivery friction or independent workload scaling.
- Read replicas, partitioning, or sharding require a measured database limit after query, index, and
  retention work.
- Multi-region requires a recovery objective that one-region backup/restore cannot satisfy.

When a gate is met, update the contract, baseline, observability target, rollback path, and evidence
status in the same technical change. Git history carries completed project-process history.
