# Kubernetes Assets — Deferred/Post-MVP

Kubernetes is a future platform option for API Observatory, not a historical
surface. These cloud-neutral manifests, Helm charts, and Kustomize overlays are
kept as design and validation material for a later, evidence-triggered stage.
They are not a supported local deployment workflow and must not be presented as
runtime or production evidence.

The current supported runtime is app-owned local Compose. AWS Stage 0 is the
next portfolio direction and remains a configuration/decision claim until an
approved live deployment is verified. See the repository [README](../README.md)
and [evolution plan](../docs/architecture/evolution-plan.md).

## Post-MVP Scope

The previous `k3s-*` recipe names are intentionally unavailable: no k3d,
`kubectl apply`, image-build, secret, or teardown command is currently
supported by the `Justfile`. Run `just help-kubernetes` for the same boundary.

Before enabling a Kubernetes workflow, reconcile these assets with the current
app contract, then add named recipes only for stable, supported workflows.
Native `kubectl`, Helm, and k3d commands remain explicit operator work and need
a reviewed target, plan/change view, and approval before mutation.

## Included Assets

- `k3d.yaml` — deferred local-cluster configuration using the `api-observatory`
  naming namespace.
- `overlays/local/` — deferred local Kustomize overlay and example secret
  template; no real secret belongs in this repository.
- `charts/` and `helm-values/` — cloud-neutral Helm material for future review.
- `manifests/` — base workloads, services, autoscaling, RBAC, and NetworkPolicy
  material.

## Activation Evidence

Activation requires a measured capacity, availability, ownership, or deployment
trigger; a reconciled app/service topology and images; resource requests and
limits; default-deny plus matching NetworkPolicies; cloud-specific settings in
overlays; and an approved, exercised local workflow. Until then, validate chart
syntax with `just helm-lint` only.
