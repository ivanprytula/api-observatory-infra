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
2. The publisher applies the infra-owned promotion script to current infra `main` and opens or
   updates one bot-owned pull request for the target. Only the current app `main` tip may replace its
   candidate.
3. A human reviews and merges the exact image-lock change; this merge is the deployment approval.
4. A green infra `main` CI run applies that merged desired state to the selected target. Manual
   dispatch can only replay the desired state already committed on `main`.
5. The current implementation only accepts the `dev` lane for the `aws-dev` target.

Automated image promotion preserves `enabled_profiles` from infra `main`. Profile selection is an
infrastructure/runtime decision and changes through a separate reviewed PR.

This keeps the promotion path simple while preserving room for later stage and prod-like environments
without changing the underlying release contract.
