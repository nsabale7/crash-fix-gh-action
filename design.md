# SP-1 Technical Design

## Architecture Overview

```
crash-fix-gh-action/
├── action.yml                    # Action manifest: inputs, outputs, runs (composite)
├── action/
│   ├── crash-payload-schema.json # JSON schema for repository_dispatch client_payload
│   ├── validate.sh               # Validates required inputs; exits non-zero on failure
│   ├── build-prompt.sh           # Assembles structured prompt → $PROMPT_FILE
│   ├── branch.sh                 # Creates and pushes crash-fix/<sig>-<run-id> branch
│   ├── commit.sh                 # Stages diff, commits, pushes; fails on empty diff
│   ├── open-pr.sh                # Opens PR via gh CLI; writes outputs
│   ├── pr-template.md            # Mustache-style PR body template
│   └── agents/
│       ├── claude/
│       │   ├── install.sh        # Installs Claude Code CLI (npm -g @anthropic-ai/claude-code)
│       │   └── run.sh            # Runs claude --print < $PROMPT_FILE > $OUTPUT_FILE
│       ├── aider/
│       │   ├── install.sh        # stub: echo "not implemented"; exit 1
│       │   └── run.sh            # stub: echo "not implemented"; exit 1
│       ├── codex/
│       │   ├── install.sh        # stub
│       │   └── run.sh            # stub
│       └── gemini/
│           ├── install.sh        # stub
│           └── run.sh            # stub
└── .github/
    └── workflows/
        └── ci.yml                # Lint + unit tests on PRs
```

`action.yml` uses `runs: using: composite` so every step is a plain shell script — no Docker build, no Node bundle for v1.

---

## Data Flow

```
Trigger (workflow_dispatch / repository_dispatch)
  │
  ▼
[1] validate.sh
    Checks required inputs (crash-id, signature, app-version, create-time, api-key, github-token).
    Fails fast with a descriptive message if any are missing.
  │
  ▼
[2] build-prompt.sh
    Writes a structured markdown prompt to $PROMPT_FILE (/tmp/crash-prompt.md).
    Includes: crash signature, stack trace, app version, create time, device info,
    occurrence count, and instruction to limit edits to implicated files.
  │
  ▼
[3] action/agents/<name>/install.sh
    Installs the selected agent CLI on the runner.
    Exports the correct provider API key env var
    (ANTHROPIC_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY).
  │
  ▼
[4] branch.sh
    git checkout -b crash-fix/<signature>-<run-id> from base-branch.
    Pushes the empty branch to origin.
  │
  ▼
[5] action/agents/<name>/run.sh
    Invokes the agent non-interactively.
    Reads $PROMPT_FILE; writes change summary to $OUTPUT_FILE (/tmp/agent-output.md).
    REPO_PATH is the checked-out workspace root.
  │
  ▼
[6] commit.sh
    git diff --exit-code HEAD — if no changes, fail (FR-6).
    git add -A; git commit -m "fix: agent-proposed fix for <signature>"
    git push origin <branch>
  │
  ▼
[7] open-pr.sh
    gh pr create --base <base-branch> --head <branch> --body "$(cat pr-body.md)"
    Writes pr-url, pr-number, branch to $GITHUB_OUTPUT.
    Appends pr-url to $GITHUB_STEP_SUMMARY.
```

---

## Agent Seam Contract

Every agent implementation under `action/agents/<name>/` MUST honor this contract:

### Environment Variables (provided by the action before calling run.sh)

| Variable | Description |
|---|---|
| `AGENT_API_KEY` | Provider API key (value of the `api-key` input). The run.sh re-exports this as the provider-specific var (e.g., `ANTHROPIC_API_KEY`). |
| `REPO_PATH` | Absolute path to the checked-out repository workspace. The agent MUST make edits under this path only. |
| `PROMPT_FILE` | Absolute path to the prompt file (e.g., `/tmp/crash-prompt.md`). The agent reads its instructions from here. |
| `OUTPUT_FILE` | Absolute path where the agent writes its change summary (e.g., `/tmp/agent-output.md`). MUST exist and be non-empty after a successful run. |

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | Agent ran successfully and made at least one file edit. |
| `1` | Agent ran but produced no changes (pre-empts commit.sh empty-diff check). |
| `2+` | Agent failed (auth error, network timeout, internal error). |

### install.sh Contract
- MUST be idempotent (safe to call if already installed).
- MUST exit `0` on success, non-zero on failure.
- MUST NOT require interactive input.

---

## Key Design Decisions

### Pluggable Agent Pattern
Agent dispatch is purely file-system driven: the action resolves `action/agents/$AGENT/install.sh` and `action/agents/$AGENT/run.sh` from the `agent` input. Adding an agent requires no changes outside its own directory (NFR-3). Unknown agent names fail at the file-resolution step with a clear error.

### No Direct Default-Branch Pushes
`branch.sh` always creates a new branch. `open-pr.sh` uses `gh pr create`, which opens a PR — it cannot commit to the base branch. The required `github-token` scopes (`contents: write`, `pull-requests: write`) do not include bypassing branch protection. This is a structural guarantee, not just a policy.

### Empty Diff = Hard Fail
`commit.sh` runs `git diff --exit-code HEAD` before staging. If the working tree is clean, the script exits non-zero immediately. This prevents silent no-ops (FR-6) and ensures `pr-url` is only set when real changes exist.

### Composite Action (No Docker)
Using `runs: using: composite` avoids Docker build time on the runner and keeps the action usable in any GitHub-hosted runner environment without a container registry. The tradeoff is that install.sh steps add latency; this is acceptable for v1 where agent install time dominates anyway.

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-1 | Claude Code CLI changes its non-interactive invocation interface between releases | Medium | High | Pin the CLI version in install.sh (`npm install -g @anthropic-ai/claude-code@<version>`); add a CI check that re-runs install against a known version. |
| R-2 | Agent produces a diff that breaks the target repo's tests | Medium | Medium | Out of scope for v1 (PR is human-reviewed before merge); document that PR CI on the consumer repo is the safety net. |
| R-3 | `AGENT_API_KEY` leaks into logs via agent CLI debug output | Low | Critical | Wrap run.sh in a GitHub Actions secret masking step; add a log-scan CI job that greps for known key prefixes (`sk-ant-`, `sk-`, etc.) in captured output. |
| R-4 | Stack trace exceeds GitHub Actions input size limit (~100 KB) | Low | Medium | Truncate stack-trace input to 50 KB in validate.sh with a warning; document the limit in README. |
| R-5 | `gh` CLI not present or outdated on ubuntu-latest runner | Low | High | Pin `gh` version check in open-pr.sh; ubuntu-latest ships gh by default — add a version assertion in CI. |

---

## Testing Strategy

### Unit Tests (shell script mocks)
- Each script (`validate.sh`, `build-prompt.sh`, `commit.sh`) is tested in isolation using BATS (Bash Automated Testing System).
- Agent calls are mocked by placing a fake `run.sh` on `$PATH` that writes a canned output file and exits 0.
- Tests cover: missing required fields → exit 1; empty diff → exit 1; happy path → correct outputs.
- Run in CI on every PR via `ci.yml`.

### Integration Tests (act local runner)
- `act` runs the full composite action locally against a throwaway test repository.
- A mock agent stub simulates a successful edit (appends a comment to a scratch file).
- Verifies: branch name format, PR body contains all required fields, outputs are set, no push to base-branch.
- Run locally by developers; optionally gated in CI via a self-hosted runner with `act` installed.

### End-to-End Tests (real workflow_dispatch)
- A dedicated test repository (`crash-fix-e2e-target`) hosts a simple app with a known crash signature.
- A `workflow_dispatch` trigger fires the action with a real `ANTHROPIC_API_KEY`.
- Pass criteria: PR opened on the test repo, branch named correctly, PR body complete, no commit on `main`.
- Run manually for release candidates; not run on every PR due to cost and latency.
