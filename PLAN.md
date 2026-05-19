# SP-1 Sprint Plan

## Goal

Ship a working GitHub Action that accepts a crash payload, runs Claude Code non-interactively against the target repo, and opens a pull request with a proposed fix — with agent stubs for aider, codex, and gemini ready to wire in future sprints.

---

## Tasks

### T-1 — Scaffold repo structure and action.yml inputs/outputs
**Description:** Create the top-level directory layout (`action/`, `action/agents/claude/`, `action/agents/aider/`, etc.), write `action.yml` with all inputs and outputs declared, and add `action/crash-payload-schema.json`. No logic yet — just structure and manifest.

**Done criteria:** `action.yml` validates via `actionlint`; all inputs from FR-1 and outputs from FR-4 are declared with correct types and descriptions; directory skeleton matches the architecture in `design.md`.

**Riskiest assumption:** The Claude Code CLI supports a fully non-interactive mode (`--print` or equivalent) that works on a headless runner. This must be confirmed in T-1 by reading the CLI docs — if not supported, the entire T-3 implementation path changes. Validate before T-3 begins.

**Dependencies:** none (first task)

---

### T-2 — Build crash-payload validator and prompt builder
**Description:** Implement `action/validate.sh` (checks required inputs, truncates stack-trace >50 KB, exits non-zero with descriptive message on failure) and `action/build-prompt.sh` (writes a structured markdown prompt to `$PROMPT_FILE` using all crash payload fields).

**Done criteria:** BATS unit tests pass for: all required fields present → exit 0; each required field missing individually → exit 1 with field name in error; stack-trace >50 KB → truncated with warning; prompt file contains all provided fields.

**Dependencies:** T-1 (directory structure must exist)

---

### T-3 — Implement Claude agent install.sh and run.sh
**Description:** Write `action/agents/claude/install.sh` (pins and installs Claude Code CLI via npm, idempotent) and `action/agents/claude/run.sh` (re-exports `AGENT_API_KEY` as `ANTHROPIC_API_KEY`, invokes the CLI non-interactively with `$PROMPT_FILE`, writes output to `$OUTPUT_FILE`, exits per the agent seam contract).

**Done criteria:** The full install + run sequence completes successfully inside an `act`-simulated `ubuntu-latest` sandbox without a TTY; `$OUTPUT_FILE` is non-empty after a successful run; agent seam contract exit codes are implemented correctly.

**Riskiest assumption (same as T-1):** Confirm the non-interactive CLI flag before writing run.sh.

**Dependencies:** T-1 (scaffold), T-2 (prompt file must be present for run.sh to read)

---

### T-4 — Scaffold aider/codex/gemini stubs returning "not implemented"
**Description:** For each of `aider`, `codex`, and `gemini`: write `install.sh` and `run.sh` that print `"not implemented"` to stderr and exit 1. No real installation or invocation logic.

**Done criteria:** Stubs exist at the correct paths (`action/agents/<name>/install.sh`, `action/agents/<name>/run.sh`); each exits 1 with "not implemented" in stderr; CI (actionlint + BATS) is green.

**Dependencies:** T-1 (directory structure)

---

### T-5 — Implement branch creation and commit logic
**Description:** Write `action/branch.sh` (creates `crash-fix/<signature>-<run-id>` branch from `base-branch`, pushes empty branch to origin) and `action/commit.sh` (checks for empty diff → fail, stages all changes, commits with a descriptive message, pushes branch).

**Done criteria:** Branch is named exactly `crash-fix/<signature>-<run-id>` (verified by integration test); commit is present on the branch; empty-diff case exits non-zero with a clear message before `git commit` is called; no commit is ever made to `base-branch`.

**Dependencies:** T-3, T-4 (agent must have run and produced a diff before commit.sh is called)

---

### T-6 — Implement PR creation with full body template
**Description:** Write `action/pr-template.md` with placeholders for all required PR body fields. Write `action/open-pr.sh` that hydrates the template and calls `gh pr create`. Write PR outputs (`pr-url`, `pr-number`, `branch`) to `$GITHUB_OUTPUT` and append `pr-url` to `$GITHUB_STEP_SUMMARY`.

**Done criteria:** PR body includes: crash signature, stack trace (if provided), app version, create time, device info (if provided), occurrence count (if provided), agent name, and agent change summary; all three outputs are set in `$GITHUB_OUTPUT`; `pr-url` appears in the step summary; PR targets `base-branch`, not any other branch.

**Dependencies:** T-5 (branch must be pushed before PR can be opened)

---

### T-7 — End-to-end test with workflow_dispatch on test repo
**Description:** Configure a dedicated test repository with a simple app containing a known crash signature. Fire `workflow_dispatch` with a real `ANTHROPIC_API_KEY`. Verify the full flow end-to-end.

**Done criteria:** A PR is opened on the test repo; PR branch is named `crash-fix/<signature>-<run-id>`; PR body includes all required fields; no commit appears on `main`; no secret values appear in the PR body or Actions log.

**Dependencies:** T-6 (full action must be implemented)

---

## Task Dependencies

```
T-1 ──► T-2 ──► T-3 ──┐
  │                    ├──► T-5 ──► T-6 ──► T-7
  └──────► T-4 ────────┘
```

- T-1 must complete before T-2, T-3, and T-4 can start.
- T-2 must complete before T-3 (prompt file contract).
- T-3 and T-4 must both complete before T-5 (agent seam fully defined).
- T-5 must complete before T-6 (branch must exist for PR).
- T-6 must complete before T-7 (action must be fully implemented).

---

## Riskiest Assumption

**Claude Code CLI non-interactive mode** — the entire T-3 implementation depends on the CLI supporting a headless, non-TTY invocation that reads from a file and writes output to stdout/file without interactive prompts. Validate this in T-1 (read CLI docs, run a smoke test in a local Docker container) before writing any T-3 code. If the CLI requires TTY or interactive confirmation, an alternative invocation strategy (e.g., `expect`, API call instead of CLI) must be chosen before T-3 begins.

---

## Success Metrics

- All tasks T-1 through T-7 marked done.
- End-to-end test (T-7) passes: PR opened, branch named correctly, no push to main.
- No secrets leaked in any log, PR body, or artifact (verified by log-scan in T-7).
- `actionlint` and BATS unit tests green on the final commit.

---

## Constraints

- Each task is scoped to be completable in a single working session (≤4 hours).
- No Docker images required for v1; composite action only.
- Agent stubs (T-4) must not block T-5/T-6/T-7 — they are independent of the Claude path.
- All work targets `ubuntu-latest` runners; no macOS or Windows runner dependencies.
