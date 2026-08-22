# AGENTS.md — Rules for AI Coding Agents

Global rules for agents working in this repository. Generic behavior rules live in `../agent-forge/instructions/agent-behavior.instructions.md`. Project-specific overrides live in `CLAUDE.md`.

## Git stash

**Never drop git stashes.** Only use `git stash pop` or `git stash apply`. Preserve stashes across sessions in all repositories.

## Patterns & Gotchas

- _(e.g., "The v1/users API is deprecated — use v2/users instead.")_
- _(e.g., "When adding a new enum value, also update `constants.ts` or tests will fail.")_
- _(e.g., "The CI uses Node 20 — don't use Node 22 features.")_

## Progressive-loading routes

Read the relevant skill or instruction file before producing significant infrastructure changes in that area:

- **Terraform/Ansible** → `../agent-forge/skills/terraform-plan-review/SKILL.md`, `../agent-forge/skills/terraform-checkov-triage/SKILL.md`, `../agent-forge/skills/ansible-playbook-patterns/SKILL.md`
- **Bash** → `../agent-forge/instructions/bash.instructions.md`
- **Markdown** → `../agent-forge/instructions/markdown.instructions.md`
- **Design/architecture** → `../agent-forge/instructions/design-patterns.instructions.md`, `../agent-forge/instructions/solid-principles.instructions.md`
- **Project architecture** → `docs/architecture/evolution-plan.md`, `docs/architecture/baseline-checklist.md`, `docs/overview.md`

## Instruction sync rule

Whenever you add or update an instruction file listed in **Progressive-loading routes**, check whether the sibling app repository (`api-observatory`) has the same instruction file. If it does, update both repos to keep them in sync. If the sibling repo does not have it, update only the repo you were asked to modify.

## Central agent standards

Shared agent standards are maintained in `agent-forge`:

- Git workflow → `../agent-forge/instructions/git-workflow.instructions.md`
- Repo standards → `../agent-forge/instructions/agent-behavior.instructions.md`

## Python execution

- Use `uv` for Python dependency management.
- For running Python modules, scripts, and tests in the shell, use `uv run ...`, not `python -c ...` or `python3 -c ...`.

## IaC pre-commit guardrails

- **Use `just` recipes for Terraform workflows.** Do not run `terraform` commands directly unless debugging.
- **Run `terraform fmt` before committing.** It is enforced by pre-commit (`terraform_fmt`).
- **Run `checkov` manually only when pre-commit is skipped.** Use `uv run pre-commit run checkov --all-files` otherwise.
- **Use `ansible-lint` via pre-commit.** Do not invoke it directly with custom args.
