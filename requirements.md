# SP-1 Requirements

## Functional Requirements

### FR-1 — Crash Payload Ingestion
The action MUST accept a crash payload via GitHub Actions inputs: `crash-id` (required), `signature` (required), `app-version` (required), `create-time` (required, ISO 8601), `stack-trace` (optional), `subtitle` (optional), `device-info` (optional), and `occurrence-count` (optional). Missing required fields MUST cause the action to fail with a descriptive error before any agent is invoked.

### FR-2 — Branch Creation
The action MUST check out the target repository on a fresh branch named `crash-fix/<signature>-<run-id>` forked from the configured `base-branch` (default: `main`). The branch MUST NOT already exist; if it does, the action MUST fail.

### FR-3 — Agent Invocation (Claude)
The action MUST invoke the Claude Code CLI non-interactively using the `ANTHROPIC_API_KEY` derived from the `api-key` input. The agent MUST receive the crash context as a structured prompt written to a temp file (`PROMPT_FILE`). Agent output (change summary) MUST be captured to a temp file (`OUTPUT_FILE`). The invocation MUST be non-interactive; any TTY requirement is a hard failure.

### FR-4 — PR Creation
After the agent run, the action MUST commit the modified files, push the branch, and open a pull request against `base-branch`. The action MUST expose three outputs: `pr-url`, `pr-number`, and `branch`. PR creation MUST use the `github-token` input.

### FR-5 — Multi-Agent Scaffolding
The action MUST ship stub implementations for `aider`, `codex`, and `gemini` under `action/agents/<name>/install.sh` and `run.sh`. Stubs MUST exit with a non-zero code and print "not implemented" so callers get a clear error. No changes to `action.yml` or the prompt builder are required to add a new agent.

### FR-6 — Empty-Diff Failure
If the agent produces no file changes (empty diff after the run), the action MUST fail with a clear error message and MUST NOT open a PR. Silent no-ops are prohibited.

### FR-7 — PR Content
The PR body MUST include: crash signature, stack trace (if provided), app version, create time, device info (if provided), occurrence count (if provided), agent name used, and the agent's change summary from `OUTPUT_FILE`. A structured PR template (`action/pr-template.md`) provides the skeleton.

### FR-8 — Security: No Direct Default-Branch Pushes
The action MUST NEVER push commits directly to `base-branch`. All changes MUST go through the PR flow. The action MUST NOT require or accept branch-protection bypass tokens. If `base-branch` protection rules block a direct push, this MUST be treated as expected behavior, not a bug.

---

## Non-Functional Requirements

### NFR-1 — Reliability
The action MUST complete successfully (or fail with a clear, actionable error) on `ubuntu-latest` GitHub-hosted runners without manual runner setup. Transient network failures during agent install MUST be retried at least once before failing.

### NFR-2 — Security and Secret Handling
`api-key` and `github-token` MUST be passed only via GitHub Actions secrets and mapped to environment variables scoped to individual steps. They MUST NOT appear in log output, PR body, commit messages, or any artifact. The action MUST NOT write secrets to disk in plaintext.

### NFR-3 — Extensibility: New Agent = One PR
Adding a new coding agent MUST require only adding `action/agents/<name>/install.sh` and `run.sh` — no changes to `action.yml`, the prompt builder, or the PR template. The agent selection dispatch MUST be data-driven (directory lookup), not a hardcoded switch.

### NFR-4 — Observability
Each major step (payload validation, branch creation, agent install, agent run, commit, PR creation) MUST emit a distinct, human-readable GitHub Actions step summary or log line. The action MUST surface the `pr-url` in the step summary on success. On failure, the step that failed and the reason MUST be identifiable from the Actions run log without inspecting runner state.

---

## Constraints

- MUST run on `ubuntu-latest` GitHub-hosted runners without custom runner images.
- MUST use GitHub Actions native constructs (`action.yml`, step outputs, secrets, `GITHUB_TOKEN`) — no external orchestration (Kubernetes, Lambda, etc.) may be required at runtime.
- Agent CLIs are installed at job runtime; they MUST NOT be pre-baked into a container image for v1.
