# Recovery Guide

Use this guide to select a bounded response path and the owning source. It does not claim that a
production environment or every recovery script has been exercised against the current
three-service Stage 0 contract.

Restore, replay, restart, and chaos operations can destroy or duplicate data or interrupt services.
Inspect exact targets, preserve evidence, and obtain approval before destructive or live-cloud use.

## Common Triage

1. Confirm the affected service and current immutable image identity.
2. Check health/readiness, then the matching Prometheus signal and correlated logs.
3. Separate application failure from database, broker, provider, or platform failure.
4. Prefer recovery of the dependency; roll back only with migration compatibility understood.
5. Repeat health and one authenticated critical path, then record recovery time and uncertainty.

Application signal meaning and debugging steps live in the app
[observability guide](https://github.com/ivanprytula/api-observatory/blob/main/docs/08-operations/observability.md).
Infra dashboards, alerts, and collection boundaries live in
[platform observability](observability.md).

## Scenario Map

| Scenario | Primary evidence | Bounded response |
| --- | --- | --- |
| Error/latency SLO breach | SLO dashboard, handler metrics, correlated logs; app Tempo only when its local monitoring profile is running | Identify the failing boundary, mitigate the dependency or roll back the immutable image, then recheck the same window |
| Open circuit breaker | `pipeline_circuit_breaker_state`, dependency health, application logs | Restore the dependency and allow automatic state recovery; do not invent an admin reset path |
| DLQ/consumer lag | Broker health, consumer lag, sampled failed payload metadata | Fix the consumer/schema/dependency first; replay only a bounded idempotent batch with retained before/after offsets |
| Backup/restore | Backup artifact identity, checksum, schema/version, restore target | Restore only to an explicit disposable target first; verify migrations and critical reads before considering promotion |
| Fault/chaos exercise | Baseline health/signals, injected fault, recovery time | Use one reversible local fault, verify cleanup, and retain the before/failure/recovery evidence |

## Backup and Restore

[`scripts/backup.sh`](../../scripts/backup.sh) and [`scripts/restore.sh`](../../scripts/restore.sh)
contain local PostgreSQL/MongoDB and Azure Blob-era behavior. AWS variants are
[`backup-s3.sh`](../../scripts/backup-s3.sh) and [`restore-s3.sh`](../../scripts/restore-s3.sh).
The restore script drops and recreates its configured database.

These scripts still carry legacy database/service assumptions and are not verified Stage 0 recovery
proof. Before use, inspect database name, host, artifact format, storage destination, credentials,
and cleanup behavior. Never point a rehearsal at an unverified remote/production target. A backup
is not evidence until a restore to a disposable target has been checked.

## Circuit Breaker and DLQ

Circuit-breaker behavior is app-owned under
[`libs/platform`](https://github.com/ivanprytula/api-observatory/tree/main/libs/platform) and its
focused tests. Kafka/DLQ behavior is app-owned by the ingestor broker/event modules. This repository
provides alert/dashboard configuration only.

Do not copy payloads through shell pipelines or advance offsets from documentation. Use the current
producer/consumer contract, confirm idempotency, preserve a sample and offsets, constrain batch
size/rate, and verify lag plus application outcomes after replay.

## Fault Exercises

[`scripts/chaos.sh`](../../scripts/chaos.sh) is an infrastructure experiment with legacy container
targets; it must be reviewed before use and is not current Stage 0 proof. Prefer the app-owned
[performance/failure worksheet](https://github.com/ivanprytula/api-observatory/blob/main/docs/05-development/performance-and-failure-lab.md)
and maintained focused verifier for current local evidence.

After any exercise, verify that temporary containers/networks/processes are cleaned up and that no
persistent user data or cloud resource was unintentionally changed.

## Evidence Boundary

Record the environment, image/config version, trigger, signal, action, recovery time, validation,
and remaining uncertainty. Configuration, dashboards, or a written procedure without an exercised
failure/recovery path remain **Decision** or **Lab** evidence, not production ownership.
