# Infrastructure CI

The executable source of truth is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).
This repository validates platform configuration and never acts as an application workload deployment
control plane.

## Validation Gates

Terraform format/validate, TFLint, Checkov, Ansible lint, YAML lint, ShellCheck, Ruff,
documentation command checks, workflow reference checks, secret scanning, and the MVP platform
contract test validate committed configuration. A passing workflow proves static validation only; it
does not prove that Terraform was applied, a workload was deployed, or recovery was exercised.

Short-lived task branches target `main`. Protect `main` with pull requests and the stable
`CI / Merge gate`. Terraform applies, Ansible bootstrap, restores, and teardown require an explicit
operator decision and target review; CI never authorizes a cloud mutation.

For the app/platform boundary and ownership model, see [docs/overview.md](overview.md).
