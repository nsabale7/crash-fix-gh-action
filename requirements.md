# Requirements — SP-1 Crash Auto-Fix GitHub Action

## Base Branch
`main` — branch to fork from and merge back to.

## Goal
Ship a reusable GitHub Action that, given a crash payload (signature, stack trace, app version, device info), checks out the target repo, invokes a pluggable coding agent CLI in non-interactive mode to investigate and fix the crash, and opens a pull request with the proposed change. v1 ships **Claude Code** as the wired agent; `aider`, `codex`, and `gemini-cli` are scaffolded behind the same seam for future wiring. The Action is the deliverable — how the crash payload reaches GitHub is out of scope.

## Scope

**A reusable Action published from this repo (`action.yml` + supporting scripts):**

- **Action contract:** typed inputs covering crash fields (signature, stack trace, app version, device info, occurrence count, …), an `agent` selector (default `claude`), a generic `api-key` secret, and a `base-branch` config. Outputs at minimum the PR URL.
- **Action body:** checks out the consumer repo on a new branch, dispatches to the selected agent's `install.sh` to set up its CLI, runs the agent's `run.sh` non-interactively with the crash prompt, commits the diff, opens a PR against the consumer's default branch.
- **Pluggable agent seam:** each agent lives at `action/agents/<name>/{install.sh,run.sh}`. v1 fully wires `claude`; `aider`, `codex`, `gemini` ship as scaffolded folders whose scripts exit "not yet implemented." Adding a new agent later is a self-contained PR with no changes to `action.yml`, the prompt builder, or the PR template.
- **PR contents:** title and body include the crash signature, full stack trace, app version, the code-change summary, and why the change is believed to fix the crash.
- **Demo workflows in this repo** (`.github/workflows/`) showing both invocation paths:
  - `workflow_dispatch` — manual/API invocation with crash fields as inputs (used for testing and for callers that prefer the dispatch API).
  - `repository_dispatch` — listens for a custom event type and unpacks crash fields from `client_payload` (used by external dispatchers like a Cloud Function or webhook).
- **README** documenting how a consumer repo adopts the Action: `uses: org/crash-fix-gh-action@v1`, required secrets, input reference, an example workflow for each trigger, and instructions for adding a new agent.

## Out of Scope

- **Firebase Cloud Function, Crashlytics integration, BigQuery, any crash-source plumbing** — the Action assumes a caller hands it the payload; building that caller is a separate project.
- **Direct commits to the default branch** — every change must go through a PR (per README "never committed directly to your main branch").
- **Auto-merge or auto-deploy** — humans always review before merge.
- **Crash deduplication / batching** — one invocation → one PR. Grouping recurrences is a follow-up.
- **Non-fatal events / ANRs** — the Action's input schema is shaped around fatal-crash fields for v1.
- **Retry / dead-letter logic** for failed runs — basic logging only; reliability hardening is a follow-up.
- **Cost guardrails** (agent spend caps, rate limits) — sensible defaults only.
- **Self-hosted runners, custom agent containers** — target GitHub-hosted `ubuntu-latest` runners; agents are installed at runtime via their official CLIs.
- **Wiring non-Claude agents** — `aider`, `codex`, and `gemini` ship as scaffolded folders with stub scripts only. The seam exists; the implementations are follow-up work.
- **Updates to any target Android app** — this repo ships the Action; consumer repos own their own code.

## Constraints

- **Action type:** composite Action defined by an `action.yml` at the repo root, consumable via `uses: org/crash-fix-gh-action@<ref>`.
- **Triggers supported by demo workflows:** `workflow_dispatch` and `repository_dispatch` must both work end-to-end on a test repo.
- **Agent install:** each agent's CLI is installed at runtime by its `install.sh` (no third-party setup actions). For Claude v1 this is `npm install -g @anthropic-ai/claude-code`.
- **Secrets:** the Action requires `AGENT_API_KEY` (provider key matching the selected `agent`) and a GitHub token (PAT or App-minted) with permission to open PRs on the consumer repo. Sourced from GitHub Action secrets — never in code or logs.
- **Selected agent** must run in non-interactive mode within the Action; for Claude v1, the MCP server loop must work in that context (riskiest assumption — smoke-test early).
- **No production data:** development and tests run against a private test repo only.
- **Runtime latency** is not a hard SLA for v1 — minutes is acceptable.

## Acceptance Criteria

- [ ] A test repo consuming `uses: org/crash-fix-gh-action@<ref>` with `agent: claude` produces a PR end-to-end when invoked via `workflow_dispatch` with crash inputs.
- [ ] The same Action produces a PR when invoked via `repository_dispatch` with the crash payload in `client_payload`.
- [ ] PR title and body contain the crash signature, full stack trace, affected app version, and a human-readable summary of the proposed fix.
- [ ] The PR's diff is scoped only to files implicated by the stack trace — no shotgun changes across unrelated files.
- [ ] Nothing is ever pushed directly to the consumer's default branch; every change is a PR.
- [ ] Action logs include enough context (run id, crash signature, agent, PR url) to debug a failed run.
- [ ] All secrets are sourced from GitHub Action secrets — no secrets in code or logs.
- [ ] Repeating the trigger with the same crash signature still produces a new PR — no silent deduplication.
- [ ] `action/agents/` contains folders for `claude`, `aider`, `codex`, `gemini`. The non-claude folders each contain `install.sh` and `run.sh` that exit non-zero with a "not yet implemented" message; the seam itself is verified by selecting one of those agents and observing a clean failure.
- [ ] README documents inputs, outputs, required secrets, provides a working example workflow for both `workflow_dispatch` and `repository_dispatch`, and explains how to add a new agent.
