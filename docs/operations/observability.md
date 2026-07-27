# Platform Observability

This repository owns platform-oriented collection, alert routing, dashboards, and runtime
configuration. Application metric meaning, trace semantics, and request debugging are app-owned:
see the [application observability guide](https://github.com/ivanprytula/api-observatory/blob/main/docs/08-operations/observability.md).

## Current Assets

| Asset | Ownership |
| --- | --- |
| [`prometheus.yml`](../../monitoring/prometheus.yml) and local variant | Scrape targets and rule loading |
| [`rules/`](../../monitoring/rules/) | Golden-signal, readiness, saturation, and queue alerts |
| [`alertmanager.yml`](../../monitoring/alertmanager.yml) | Alert routing/inhibition configuration |
| [`promtail.yml`](../../monitoring/promtail.yml) | Container log shipping configuration |
| [`grafana/`](../../monitoring/grafana/) | Provisioned data sources and infrastructure/business/SLO dashboards |

These are configuration assets, not proof of a running production monitoring service. Some targets
and dashboards cover later service shapes; validate them against the app-owned three-service
contract before a live deployment.

## Signal Boundary

- The application exposes health/readiness, Prometheus metrics, structured logs, and optional OTLP
  traces.
- Infra configures how a target environment scrapes, stores, displays, and routes those signals.
- Correlation IDs and metric labels must remain stable enough for dashboards and recovery queries.
- Sensitive values and payloads must not enter logs, labels, alerts, or retained evidence.

The infra repository currently provisions no Loki service and no trace backend. Its Promtail and
Grafana Loki configuration expects a compatible runtime-provided endpoint. Ansible keeps OTEL
disabled by default, while a local Kubernetes overlay still names a Jaeger OTLP endpoint without
provisioning that backend. Those files are design/configuration evidence, not an active tracing
claim. The app repository's local Compose monitoring profile uses Tempo.

## Verification

Before relying on a target environment:

1. Match scrape targets and dashboard service names to the current deployment contract.
2. Confirm health/readiness and `/metrics` from inside the runtime network.
3. Trigger one bounded failure and retain the alert, metric, correlated log, and recovery timing.
4. Confirm alert routing does not expose secrets and that silence/inhibition behavior is understood.
5. Record missing backends or stale targets as gaps rather than fabricating successful evidence.

Use the [recovery guide](recovery-guide.md) for bounded response paths. A live SLO claim additionally
requires representative traffic, an agreed objective, retained evidence, and tested recovery.
