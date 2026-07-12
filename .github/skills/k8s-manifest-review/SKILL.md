---
name: k8s-manifest-review
description: "Review Kubernetes raw manifests, Helm charts, and Kustomize overlays for this repo's mandatory network-policy requirement, resource requests/limits, and cloud-neutral portability between AKS and EKS targets. Covers kubernetes/manifests/, kubernetes/charts/, and kubernetes/overlays/ conventions, including k3d-local vs AKS/EKS-target parity checks."
metadata:
  applyTo: "kubernetes/**/*.yml, kubernetes/**/*.yaml"
argument-hint: "concern: network-policy|resource-limits|portability|overlay-scope"
---

# Kubernetes Manifest Review — Skill

Purpose: catch missing network policies, unbounded resource usage, and cloud-coupling before a manifest is
applied to any cluster (local k3d or a real AKS/EKS target).

When to invoke: writing or reviewing anything under `kubernetes/manifests/`, `kubernetes/charts/`, or
`kubernetes/overlays/`.

## Network policy (mandatory per this repo's CLAUDE.md)

- Every Deployment/StatefulSet that creates a Service must have a corresponding NetworkPolicy — this repo
  treats network policies as mandatory for all services, not optional hardening.
- Default posture: deny-all ingress/egress at the namespace level, then explicit allow rules per service
  pair. Flag any manifest that exposes a Service without a matching NetworkPolicy as a review blocker, not a
  suggestion.
- Check policy `podSelector` labels actually match the target workload's labels — a NetworkPolicy with a
  selector typo silently does nothing, which is worse than an obviously-missing one.

## Resource requests/limits

- Every container spec needs `resources.requests` and `resources.limits` for both `cpu` and `memory`. No
  limits means one runaway pod can starve the node — especially relevant given this repo's free-tier cloud
  targets (Azure B1s, AWS t2.micro), which have very little headroom.
- Requests should reflect realistic steady-state usage, not the limit value copied down — copying limits
  into requests over-reserves the (already small) node capacity.

## Cloud-neutral portability (AKS/EKS parity)

- Per this repo's convention, Kubernetes/monitoring/Helm content is cloud-neutral — a manifest should not
  hardcode Azure-specific (`kubernetes.azure.com/...`) or AWS-specific (`eks.amazonaws.com/...`) annotations
  or storage classes unless it's in a Kustomize overlay scoped to that cloud.
- StorageClass and Ingress-class references belong in overlays (`kubernetes/overlays/<cloud>/`), not in the
  base manifests/charts — check `kubernetes/overlays/` before assuming a cloud-specific value belongs in the
  shared base.

## Helm/Kustomize scope

- Helm charts in `kubernetes/charts/` should expose cloud-specific knobs (storage class, ingress
  annotations, resource sizing) as `values.yaml` parameters, not hardcode them — the same chart should
  deploy to k3d-local and AKS/EKS with only a values override.
- Kustomize overlays should patch, not duplicate — an overlay that repeats most of the base manifest instead
  of patching a small delta indicates the base isn't factored correctly.
