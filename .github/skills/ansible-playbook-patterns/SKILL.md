---
name: ansible-playbook-patterns
description: "Ansible development patterns for this repo's provisioning playbooks. Covers idempotency checks (avoiding shell/command tasks that aren't guarded by `changed_when`/`creates`), `ansible-lint` conventions, tagging strategy for selective runs, and inventory group-per-cloud patterns (azure_dev, aws_dev). Includes guidance specific to this repo's ansible/playbooks/ and ansible/inventory/ layout and ansible.cfg defaults."
metadata:
  applyTo: "ansible/**/*.yml, ansible/**/*.yaml, ansible.cfg"
argument-hint: "concern: idempotency|linting|tagging|inventory"
---

# Ansible Playbook Patterns — Skill

Purpose: keep playbooks idempotent, lintable, and consistent with this repo's cloud-per-group inventory
layout.

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

## Inventory conventions (this repo)

- Inventory uses group-per-cloud: `azure_dev`, `aws_dev` (see `ansible/inventory/`). New environments follow
  the same `<cloud>_<env>` naming.
- `ansible.cfg` at repo root holds shared defaults (inventory path, roles path, retry file location) — don't
  override these per-playbook unless there's a concrete reason; check `ansible.cfg` first before adding
  playbook-level config.
- Cloud-specific variables (region, resource group, VPC) belong in group_vars for that cloud's group, not
  hardcoded in playbook tasks — this is what keeps a playbook portable across `azure_dev`/`aws_dev`.
