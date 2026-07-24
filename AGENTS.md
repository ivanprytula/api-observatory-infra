# AGENTS.md — Rules for AI Coding Agents

Global rules for how AI coding agents (Cline, Kilo, Copilot, etc.) should behave when working on this user's
projects.

> **Project-specific overrides** for the current repo live in `CLAUDE.md`. Read that file too. The global
> rules here apply everywhere; project rules win on conflict.

---

## Brief overview

This file is deliberately lean. Three groups of rules live here:

1. **How to communicate** — priority, style, response shape, session mechanics.
2. **How to behave around files** — read scope, secrets, credential stores, `.gitignore`.
3. **Cross-project technical conventions** — short checklists and links; deep content lives in the project.

The repository's own `.github/skills/` carry the long-form, invocable procedures. AGENTS.md carries the
principles so an agent can act in any project, then points to the project files for depth.

---

## Priority

Optimize for low token usage. Be brief in chat. Prefer file edits and focused commands over long prose. Do not narrate internal reasoning, tool choice, or step-by-step plans unless asked. Do not paste large code blocks when the file can be edited directly. Do not restate the same fact twice. Do not dump large command output; summarize only the important lines.

## Read scope

Read this file first. Read only instruction files that match the files you touch. Do not read `.env`, secrets, vault files, or unrelated config unless explicitly asked. Do not scan `.venv`.

## Execution rules

Use tools immediately when the user asks to change files. Use `uv run` for Python commands, scripts, and tooling. Do not commit, amend, or create branches unless explicitly asked. Do not revert user changes unless explicitly asked. Never run `terraform apply`, `kubectl apply/delete/exec`, `helm install/upgrade/delete`, or `ansible-playbook` without first showing the user what will change (`terraform plan`, `--dry-run`, etc.) and getting explicit confirmation.

## Response style

Default shape: result, key validation, next step if needed. Keep explanations short and technical. Prefer prose over lists unless the content is inherently list-shaped. For simple tasks, one short paragraph is enough.

---

## Privacy and file access

### Respect `.gitignore`

Treat any path covered by `.gitignore`, `.dockerignore`, `.pre-commit-config.yaml` `exclude:` lists, or any other project ignore file as out of scope. Do not read, grep, or display the contents of ignored files unless the user explicitly names that specific file in that specific message. Typical ignored paths: `.venv/`, `.env`, `.env.*`, `*.tfvars`, `*.tfstate*`, `node_modules/`, `*.log`, build artifacts, `.copilot/`, `.kilo/`, `.cursor/`, `.aws/`, `.gcp/`, `.azure/`, `.ssh/`.

### Never read `.env`, `.env.*`, `*.tfvars`, `*.tfstate*`, `vault.yml`, or any local secrets file

Never read `.env`, `.env.*`, `*.tfvars` (non-`.example`), `*.tfstate*`, `vault.yml`, `secrets/`, `credentials`, or any other file that contains secrets, API keys, passwords, or tokens — even if committed (test fixtures in `.example` files are fine). If you need info from these files, ask the user to check and share only the relevant line/value, masked if needed. This overrides the general "read scope" allowance — these files are never in scope regardless of `.gitignore` status.

### Never read `~/.aws/*` (or any cloud credential store)

Never read `~/.aws/credentials`, `~/.aws/config`, `~/.aws/sso/`, `~/.aws/amazonq/`, or any file under `~/.aws/`. The same rule applies to other providers: `~/.gcp/`, `~/.azure/`, `~/.kube/config`, `~/.docker/config.json`, `~/.netrc`, `~/.boto`, `~/.config/gcloud/`, `~/.config/gh/hosts.yml`, `~/.ssh/id_*`, `~/.gnupg/`. When a hook, linter, or CI rule appears to come from a credential file, fix the *configuration* (`.pre-commit-config.yaml`, exclude lists, env-var setup) — never the credential file itself. Treat placeholder values (`test`, `example`, `AKIAIOSFODNN7EXAMPLE`) the same as real values.

### Diagnostics without exposing secrets

For credential-related bugs, use only non-sensitive metadata: file existence (`ls -la`), file size, line count, env-var *names* (not values), or redacted output (`sed 's/=.*$/=***/'`). Never echo, log, or paste the value of an access key, secret key, session token, password, API token, or vault-decrypted value. Refer to credential values only by their masked prefix (e.g. `test****`) as the hook itself does.

### When the user mentions a credentials issue

Do not try to reproduce by reading the credential file. Pivot to: (a) reading the hook's source/regex, (b) reading the *committed* file the hook flagged, (c) suggesting a non-invasive fix in the repo config. Config/credential files that are *committed* to the repo (e.g. `terraform/**/*.tf`, sample `*.tfvars.example`, `backend.*.hcl.example`) are fine to read; the rule applies to the user's private local credential store and to real state/vault files.

---

## Cross-project technical conventions

For each topic below, the principles are listed inline; the long-form guidance and invokable procedures live in `.github/skills/`. Read the relevant skill before producing significant infrastructure changes in that area.

### Security (Terraform/Ansible/K8s) → see repo `CLAUDE.md` "Security Config" section

- **State & secrets.** Never read or print `.tfstate*`, `vault.yml`, or non-`.example` `.tfvars`. Backend config lives in `backend.*.hcl.example`.
- **Change visibility.** Always run `terraform plan` (or `-out=tfplan`) before `apply`; always explain what a `kubectl`/`helm` command will change before running it.
- **Network policy.** Network policies are mandatory for all Kubernetes services — flag manifests that lack one.
- **Provider pinning.** Pin Terraform provider versions explicitly; keep AWS and Azure environments structurally parallel.

### Markdown → see app repo `.github/instructions/markdown.instructions.md` (shared convention)

Use H1 once for the document title. H2 for major sections, H3 for subsections; never skip a level. Use `` `code` `` inline, language-tagged triple backticks for blocks, `-` for unordered lists, `1.` for ordered. Link liberally to source files with line refs. Keep docs concrete.

**MD036 guardrail (always inline).** Pre-commit markdownlint MD036 fails on emphasis-only headings. Never put a standalone `**...**` line that acts as a heading. Replace with real `###`/`####` headings or convert into paragraph text.

### Bash → see app repo `.github/instructions/bash.instructions.md` (shared convention)

Shebang + metadata block. `set -o errexit -o pipefail -o nounset -o errtrace`. Trap ERR with a line-number reporter. Define `info`/`success`/`warn`/`error`/`require_command`/`command_exists` helpers at the top. Quote every variable (`"${var}"`). Never hardcode paths. `trap cleanup EXIT` for teardown. Lint with `shellcheck`.

### Design principles → see `~/.claude/CLAUDE.md` (ACROSS) and repo `CLAUDE.md` (P1-P3)

Use ACROSS as the primary design lens for any code in this repo (scripts, Ansible modules, tooling) — it prioritizes change management over structural purity. This repo's own P1-P3 engineering principles (Python-first justified polyglot, YAGNI/boring/business-first, vertical-slice estimation) apply alongside it, specifically for infra tooling decisions.

### Anti-overengineering

Before suggesting any custom implementation, check whether a well-known Terraform module, Ansible role, or Helm chart already solves the same problem. Flag abstractions (Terraform modules, Ansible roles) with fewer than 3 callers/environments. Simplest solution wins — complexity must be justified by a concrete, current requirement (e.g. this repo's actual multi-cloud layout), not a future hypothetical.

---

## Chat session reminders

- Start a new chat every 20 messages and whenever the topic changes, to keep context clean.
- At the 20th message, prepare a concise "Session Summary" (template below) and offer to paste it into a new chat.
- The first message of the new chat should be the summary, so context and continuity are preserved.

### Session Summary Template (copy/paste into new chat)

- **Session title:**
- **Date:**
- **Message count:**

- **Topics covered:**
   -

- **Key decisions:**
   -

- **Files changed / paths:**
   -

- **Commands / snippets to run:**
   -

- **Outstanding questions / next steps:**
   -

- **Brief context / notes:**
   -

(End of summary)
