---
name: ansible-playbook-patterns
description: "Ansible development patterns for the AWS MVP bootstrap. Covers idempotency, ansible-lint conventions, tagging, and the SSM-operated aws_dev inventory."
metadata:
  applyTo: "ansible/**/*.yml, ansible/**/*.yaml, ansible.cfg"
argument-hint: "concern: idempotency|linting|tagging|inventory"
---

# Ansible Playbook Patterns — Skill

Purpose: keep the AWS MVP bootstrap idempotent, lintable, and consistent with the SSM inventory.

When to invoke: writing or reviewing anything under `ansible/playbooks/` or `ansible/inventory/`.

## Idempotency

- Prefer built-in modules (`ansible.builtin.file`, `ansible.builtin.copy`, `community.*` cloud modules) over
  `shell`/`command` — they're idempotent by construction and report `changed` accurately.
- If `shell`/`command` is unavoidable, guard it: use `creates:`/`removes:` for file-existence checks, or an
  explicit `changed_when:` condition based on the command's actual output. A bare `command:` task with no
  guard always reports `changed`, which breaks idempotency reporting and CI drift detection.
- Avoid tasks that mutate state based on `ansible_date_time` or other non-deterministic facts unless the
  task is explicitly meant to run every time.

## ansible-lint conventions

- Run `ansible-lint` against changed playbooks before considering a task done — the repo has `.ansible-lint`
  at the root configuring the ruleset.
- Common findings to self-check before running the linter: missing `name:` on every task, `latest` used for
  package versions where pinning is expected, `true`/`false` instead of `yes`/`no` (lint wants boolean
  literals), and missing `become:` scoping (prefer task-level over play-level `become` when only some tasks
  need it).

## Tagging strategy

- Tag tasks so a partial run is possible: infra-provisioning tags (e.g. `provision`, `configure`,
  `deploy`) let the user run `ansible-playbook site.yml --tags configure` without re-provisioning
  infrastructure that's already up.
- Never tag destructive tasks (package removal, service stop, volume deletion) with a tag that's also
  applied to a benign task — destructive actions should be independently selectable, never accidentally
  swept in.

## Inventory conventions

- `aws_dev` is the sole inventory group and uses `amazon.aws.aws_ssm`; do not add SSH inventory as a
  fallback.
- `ansible.cfg` at repo root holds shared defaults (inventory path, roles path, retry file location) — don't
  override these per-playbook unless there's a concrete reason; check `ansible.cfg` first before adding
  playbook-level config.
- AWS-specific region and SSM variables belong in `group_vars/aws_dev`; application runtime values
  remain app-owned and are rendered from Parameter Store by the MVP role.
