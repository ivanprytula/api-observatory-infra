# Contributing

This repository uses short-lived task branches into `main`. The application repository's
[contributor lifecycle](https://github.com/ivanprytula/api-observatory/blob/main/CONTRIBUTING.md)
owns the shared branch, staging, conventional-commit, push, and pull-request rules.

## Infrastructure Task

Start from current `main` and keep application and infrastructure changes in separate commits and
pull requests:

```bash
git switch main
git pull --ff-only
git switch -c <type>/<short-task-name>
```

Run the smallest relevant static proof, then review explicit paths before committing. Common local
checks are listed by `just --list`; CI remains the executable full validation graph.

```bash
git status --short
git diff
git diff --check
git add <explicit-paths>
git diff --cached
git commit -m "<type>: <imperative summary>"
git push -u origin HEAD
gh pr create --base main --fill
```

The maintainer policy is to merge only after `CI / Merge gate` succeeds and review conversations are
resolved. GitHub does not currently enforce required checks or approvals, so verify that evidence
manually before merging.

## Cloud Safety

CI, contract validation, and a Terraform plan are static evidence only. Do not run Terraform apply,
deployment, restore, chaos, or teardown from routine contribution steps. Each live or destructive
operation requires an explicit target review and separate approval. Application image promotion
changes `environments/aws-dev/images.lock.json` through its own reviewed infra pull request.
