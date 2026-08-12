# AGENTS.md — Rules for AI Coding Agents

Global rules for AI coding agents (Cline, Kilo, Copilot, etc.) working on this repository. Project-specific overrides live in `CLAUDE.md`.

## Priority

Optimize for low token usage. Be brief in chat. Prefer file edits and focused commands over long prose. Do not narrate internal reasoning, tool choice, or step-by-step plans unless asked. Do not paste large code blocks when the file can be edited directly. Do not restate the same fact twice. Do not dump large command output; summarize only the important lines.

## Read scope

Read this file first. Read only instruction files that match the files you touch. Do not read `.env`, secrets, vault files, or unrelated config unless explicitly asked. Do not scan `.venv`.

## Execution rules

Use tools immediately when the user asks to change files. Use `uv run` for Python commands, scripts, and tooling. After refactoring — especially when changing test files or touching more than one module — run all code-quality pre-commit hooks (Ruff, terraform, Ansible, shellcheck, yamllint, docs, etc.) before running tests. Do not commit, amend, or create branches unless explicitly asked. Do not revert user changes unless explicitly asked. Never run `terraform apply` or `ansible-playbook` without first showing the user what will change (`terraform plan`, `--check`, etc.) and getting explicit confirmation.

**Validate Python edits immediately.** After editing any `.py` file, run `python -m py_compile <file>` or `ruff check <file>` on that file before moving on. Do not batch edits across many files and validate only at the end. Catch syntax/indentation errors per file, then continue.

## Response style

Default shape: result, key validation, next step if needed. Keep explanations short and technical. Prefer prose over lists unless the content is inherently list-shaped. For simple tasks, one short paragraph is enough.

## Working preferences

- Prefer small, reviewable patches over broad refactors.
- Offer one recommended approach; mention alternatives only when tradeoffs are material.
- Preserve backward compatibility unless the user explicitly authorizes a breaking change.
- Keep runtime dependencies minimal and explain why each new dependency is needed.
- When a product decision is ambiguous, present concrete options and wait for direction.
- Favor operationally simple solutions with explicit failure modes and useful observability.

## Git operations

Never use `git add .` or `git add -A`. When staging for commit, explicitly list only the files relevant to the current task. If the task scope is unclear, ask before staging. Never drop git stashes in any repository; preserve them across sessions.

## Commit messages

Write a short headline using the conventional commits framework (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, etc.). Optionally add a commit body that explains why the change was made and the motivation, but do not list the files changed — that is already visible in `git diff`.

## Privacy and file access

### Respect `.gitignore`

Treat `.gitignore`, `.dockerignore`, `.pre-commit-config.yaml` `exclude:` lists, or any project ignore file as out of scope. Do not read, grep, or display the contents of ignored files unless the user explicitly names that specific file in that specific message. Typical ignored paths: `.venv/`, `.env`, `.env.*`, `*.tfvars`, `*.tfstate*`, `node_modules/`, `*.log`, build artifacts, `.copilot/`, `.kilo/`, `.cursor/`, `.aws/`, `.gcp/`, `.azure/`, `.ssh/`.

### Never read secrets or credential stores

Never read `.env`, `.env.*`, `*.tfvars` (non-`.example`), `*.tfstate*`, `vault.yml`, `secrets/`, `credentials`, or any other file that contains secrets, API keys, passwords, or tokens — even if committed (`.env.example` fixtures are fine). If you need info from these files, ask the user to check and share only the relevant line/value, masked if needed. This overrides the general "read scope" allowance — these files are never in scope regardless of `.gitignore` status.

Never read `~/.aws/`, `~/.gcp/`, `~/.azure/`, `~/.kube/config`, `~/.docker/config.json`, `~/.netrc`, `~/.boto`, `~/.config/gcloud/`, `~/.config/gh/hosts.yml`, `~/.ssh/id_*`, `~/.gnupg/`. When a hook, linter, or CI rule appears to come from a credential file, fix the *configuration* (`.pre-commit-config.yaml`, exclude lists, env-var setup) — never the credential file itself. Treat placeholder values (`test`, `example`, `AKIAIOSFODNN7EXAMPLE`) the same as real values.

### Diagnostics without exposing secrets

For credential bugs, use only non-sensitive metadata: file existence (`ls -la`), file size, line count, env-var *names* (not values), or redacted output (`sed 's/=.*$/=***/'`). Never echo, log, or paste the value of an access key, secret key, session token, password, API token, or vault-decrypted value. Refer to credential values only by their masked prefix (e.g. `test****`) as the hook itself does.

### When the user mentions a credentials issue

Do not try to reproduce by reading the credential file. Pivot to: (a) reading the hook's source/regex, (b) reading the *committed* file the hook flagged, (c) suggesting a non-invasive fix in the repo config. Committed config/credential files (e.g. `terraform/**/*.tf`, sample `*.tfvars.example`, `backend.*.hcl.example`) are fine to read; the rule applies to the user's private local credential store and to real state/vault files.

## Cross-project technical conventions

For each topic below, the principles are listed inline; the long-form guidance and invokable procedures live in `../agent-forge/skills/`. Read the relevant skill before producing significant infrastructure changes in that area.

### Security (Terraform/Ansible) → see repo `CLAUDE.md` "Security Config" section

- **State & secrets.** Never read or print `.tfstate*`, `vault.yml`, or non-`.example` `.tfvars`. Backend config lives in `backend.*.hcl.example`.
- **Change visibility.** Always run `terraform plan` (or `-out=tfplan`) before `apply` and use Ansible check mode before an approved bootstrap when supported.
- **Provider pinning.** Pin Terraform provider versions and commit the `aws-dev` provider lock.

### Markdown → see app repo `../agent-forge/instructions/markdown.instructions.md` (shared convention)

Use H1 once for the document title. H2 for major sections, H3 for subsections; never skip a level. Use `` `code` `` inline, language-tagged triple backticks for blocks, `-` for unordered lists, `1.` for ordered. Link liberally to source files with line refs. Keep docs concrete.

**MD036 guardrail (always inline).** Pre-commit markdownlint MD036 fails on emphasis-only headings. Never put a standalone `**...**` line that acts as a heading. Replace with real `###`/`####` headings or convert into paragraph text.

### Bash → see app repo `../agent-forge/instructions/bash.instructions.md` (shared convention)

Shebang + metadata block. `set -o errexit -o pipefail -o nounset -o errtrace`. Trap ERR with a line-number reporter. Define `info`/`success`/`warn`/`error`/`require_command`/`command_exists` helpers at the top. Quote every variable (`"${var}"`). Never hardcode paths. `trap cleanup EXIT` for teardown. Lint with `shellcheck`.

### Design principles → see `~/.claude/CLAUDE.md` (ACROSS) and repo `CLAUDE.md` (P1-P3)

Use ACROSS as the primary design lens for any code in this repo (scripts, Ansible modules, tooling) — it prioritizes change management over structural purity. This repo's own P1-P3 engineering principles (Python-first justified polyglot, YAGNI/boring/business-first, vertical-slice estimation) apply alongside it, specifically for infra tooling decisions.

### Anti-overengineering

Before suggesting any custom implementation, check whether a well-known Terraform module or Ansible role already solves the same problem. Flag abstractions with fewer than 3 callers or without a current AWS requirement. Simplest solution wins; portability belongs at the application contract boundary, not in speculative provider abstractions.

## Progressive-loading routes

For security-sensitive changes:
  read `../agent-forge/instructions/security-and-owasp.instructions.md`

For Terraform/Ansible changes:
  read `CLAUDE.md` "Security Config" section
  read `../agent-forge/skills/terraform-plan-review/SKILL.md`
  read `../agent-forge/skills/terraform-checkov-triage/SKILL.md`
  read `../agent-forge/skills/ansible-playbook-patterns/SKILL.md`

For Markdown documentation:
  read `../agent-forge/instructions/markdown.instructions.md`

For Bash scripts:
  read `../agent-forge/instructions/bash.instructions.md`

For design/architecture decisions:
  read `../agent-forge/instructions/design-patterns.instructions.md`
  read `../agent-forge/instructions/solid-principles.instructions.md`

For project architecture, product decisions, or engineering topic lookups:
  read `docs/architecture/evolution-plan.md`
  read `docs/architecture/baseline-checklist.md`
  read `docs/overview.md`

## Instruction sync rule

Whenever you add or update an instruction file listed in **Progressive-loading routes**, check whether the sibling app repository (`api-observatory`) has the same instruction file. If it does, update both repos to keep them in sync. If the sibling repo does not have it, update only the repo you were asked to modify, or the repo relevant to the specific action/question.

## Central agent standards

Shared agent standards are maintained in `agent-forge`:
- Git workflow → `../agent-forge/instructions/git-workflow.instructions.md`
- Repo standards (privacy, read scope, response style) → `../agent-forge/skills/repo-standards/SKILL.md`
