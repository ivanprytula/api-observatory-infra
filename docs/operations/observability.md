# AWS MVP Platform Observability

The app repository owns application metrics, health/readiness semantics, structured logs, traces,
the local monitoring profile, and workload Prometheus configuration. This repository owns only the
AWS platform resources required by the EC2 MVP.

## Current Platform Signals

- VPC flow logs and their encrypted CloudWatch log group are defined in `aws-dev` Terraform.
- EC2, EBS, S3, ECR, IAM, and SSM state is inspected through AWS-native APIs during approved
  provisioning and recovery work.
- Application deployment readiness and smoke proof remain app-owned; infrastructure CI does not
  duplicate them.

No standalone Prometheus, Grafana, Alertmanager, log shipper, or tracing backend is deployed from
this repository. Add a platform monitoring component only when an approved live target supplies a
named signal, retention rule, response owner, and cost boundary.

## Verification

For an approved live exercise, retain the target account/region, Terraform source identity, EC2
instance identity, flow-log destination, immutable application digests, health/readiness result,
and recovery timing. Redact account identifiers and never retain credentials, secret values, or
application payloads.

Configuration and static checks remain **Decision** evidence until those records exist.
