# Promotion model

This repository uses a simple, explicit promotion model for application releases.

## Lanes

The promotion lanes are:

- `dev`: the active deployment lane for the current AWS Stage 0 target.
- `stage`: reserved for the next explicit environment once a reviewed deployment path exists.
- `prod-like`: reserved for a higher-trust operational environment after the stage lane is exercised.

## Concrete targets

The current implementation keeps the concrete environment name as `aws-dev` and the logical lane as `dev`.
This avoids a larger rename in the existing Terraform, Ansible, and workflow wiring while the platform
remains on a single active AWS target.

Future environments should keep the same lane model and use concrete target names such as:

- `aws-dev`
- `aws-stage`
- `aws-prod-like`

## Contract

1. The application repository publishes immutable images and machine-readable release metadata.
2. The infrastructure repository reviews the release metadata and promotes the selected image lock into
   the target environment.
3. The deployment workflow applies that desired state to the selected target.
4. The current implementation only accepts the `dev` lane for the `aws-dev` target.

This keeps the promotion path simple while preserving room for later stage and prod-like environments
without changing the underlying release contract.
