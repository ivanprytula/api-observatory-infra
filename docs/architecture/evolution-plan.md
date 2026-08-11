# AWS Infrastructure Evolution

> **Status:** The EC2 MVP is planned and statically validated; no live deployment is claimed.

See [docs/overview.md](overview.md) for the current platform contract and app/platform boundary.

## Principles

- Keep application contracts portable through images, environment configuration, health endpoints,
  and versioned release metadata.
- Keep platform implementations explicit. Do not build provider-switching Terraform abstractions
  before a second exercised provider exists.
- Add one operational layer at a time and retain provisioning, deployment, recovery, rollback, and
  teardown evidence before advancing.
- Production adoption requires measured delivery, scaling, availability, or ownership pressure;
  learning evidence alone does not prove a production need.

## AWS Learning Sequence

| Stage | Capability | Entry evidence |
| --- | --- | --- |
| 0 | Static EC2 Compose contract | Local image/contract proof and reviewed cost/security plan |
| 1 | Exercised EC2 MVP | Approved Terraform apply, SSM bootstrap, deployment, recovery, rollback, and teardown records |
| 2 | ECS on Fargate learning slice | Completed Stage 1 evidence and an explicit Compose-to-ECS comparison |
| 3 | EKS learning slice | Completed Stage 2 evidence and an explicit orchestration comparison |
| 4 | Another IaaS provider | Exercised evidence from Stages 1–3 |

No Fargate, EKS, or additional-provider scaffolding belongs in this repository before its entry
condition is met. Product post-MVP work may proceed independently.

## Update Policy

Update this plan only when retained evidence advances a stage or changes the current contract. Git
history carries discarded platform directions.
