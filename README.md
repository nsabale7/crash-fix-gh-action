# Crash Auto-Fix GitHub Action

A reusable GitHub Action that automatically investigates and fixes crashes using Claude Code CLI.

## Overview

Given a crash payload (signature, stack trace, app version, device info), this Action:
1. Checks out your repository on a new branch
2. Invokes a pluggable coding agent (Claude, Aider, Codex, or Gemini) in non-interactive mode
3. Runs the agent against the source code with crash context
4. Commits the proposed fix and opens a pull request

The Action is invocation-agnostic — wire it to `workflow_dispatch` for manual triggers or `repository_dispatch` for webhook integration.

---

## What It Does

Given a crash payload, the Action:

1. Checks out your repo on a fresh `crash-fix/<signature>-<run-id>` branch.
2. Locates the source files implicated by the stack trace.
3. Runs the selected coding agent with the crash context as a prompt, letting it edit files in the workspace.
4. Commits the diff, pushes the branch, and opens a PR against your default branch.
5. PR body includes the crash signature, stack trace, app version, and the agent's change summary.

Nothing is ever pushed directly to your default branch. Every change goes through a PR for human review.

---

## Quick Start

Add a workflow to your repo's `.github/workflows/`. Pick the trigger that matches how you plan to invoke this — or use both.

### `workflow_dispatch` — manual or API-triggered

```yaml
name: Crash auto-fix (manual)
on:
  workflow_dispatch:
    inputs:
      crash-id:    { required: true }
      signature:   { required: true }
      app-version: { required: true }
      create-time: { required: true }
      stack-trace: { required: false }
      subtitle:    { required: false }
      device-info: { required: false }
      agent:       { required: false, default: claude }

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: org/crash-fix-gh-action@v1
        with:
          crash-id:     ${{ inputs.crash-id }}
          signature:    ${{ inputs.signature }}
          app-version:  ${{ inputs.app-version }}
          create-time:  ${{ inputs.create-time }}
          stack-trace:  ${{ inputs.stack-trace }}
          subtitle:     ${{ inputs.subtitle }}
          device-info:  ${{ inputs.device-info }}
          agent:        ${{ inputs.agent }}
          api-key:      ${{ secrets.AGENT_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

Trigger via the GitHub UI ("Run workflow") or via the REST API:

```bash
gh workflow run crash-auto-fix.yml \
  -f crash-id=abc123 -f signature=NullPointerException \
  -f app-version=1.2.3 -f create-time=2026-05-18T12:00:00Z \
  -f stack-trace="$(cat trace.txt)"
```

### `repository_dispatch` — external dispatcher (Cloud Function, webhook, …)

```yaml
name: Crash auto-fix (dispatch)
on:
  repository_dispatch:
    types: [crash-detected]

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: org/crash-fix-gh-action@v1
        with:
          crash-id:         ${{ github.event.client_payload.crash_id }}
          signature:        ${{ github.event.client_payload.signature }}
          app-version:      ${{ github.event.client_payload.app_version }}
          create-time:      ${{ github.event.client_payload.create_time }}
          stack-trace:      ${{ github.event.client_payload.stack_trace }}
          subtitle:         ${{ github.event.client_payload.subtitle }}
          device-info:      ${{ github.event.client_payload.device_info }}
          occurrence-count: ${{ github.event.client_payload.occurrence_count }}
          agent:            ${{ github.event.client_payload.agent || 'claude' }}
          api-key:          ${{ secrets.AGENT_API_KEY }}
          github-token:     ${{ secrets.GITHUB_TOKEN }}
```

The dispatcher POSTs:

```bash
curl -X POST https://api.github.com/repos/<owner>/<repo>/dispatches \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d '{
    "event_type": "crash-detected",
    "client_payload": {
      "crash_id": "abc123",
      "signature": "NullPointerException",
      "app_version": "1.2.3",
      "create_time": "2026-05-18T12:00:00Z",
      "stack_trace": "...",
      "device_info": "Pixel 7 / Android 14",
      "occurrence_count": 42
    }
  }'
```

`client_payload` must match [`action/crash-payload-schema.json`](action/crash-payload-schema.json).

---

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `crash-id` | yes | — | Unique crash issue id |
| `signature` | yes | — | Exception class / crash title |
| `app-version` | yes | — | App version at time of crash |
| `create-time` | yes | — | ISO 8601 timestamp |
| `stack-trace` | no | — | Full stack trace text |
| `subtitle` | no | — | First line of stack trace summary |
| `device-info` | no | — | Device make/model + OS version |
| `occurrence-count` | no | — | Number of users hit |
| `agent` | no | `claude` | Coding agent to invoke. v1 wired: `claude`. Scaffolded: `aider`, `codex`, `gemini`. |
| `base-branch` | no | `main` | Branch to fork from and target the PR at |
| `api-key` | yes (secret) | — | Provider API key. Mapped to the agent's expected env var (`ANTHROPIC_API_KEY` for Claude, `OPENAI_API_KEY` for Codex/Aider, `GEMINI_API_KEY` for Gemini). |
| `github-token` | yes (secret) | — | Token used to push the branch and open the PR |

## Outputs

| Output | Description |
|---|---|
| `pr-url` | URL of the PR opened on the consumer repo |
| `pr-number` | PR number |
| `branch` | Branch name pushed |

---

## Secrets You Need

- `AGENT_API_KEY` — API key for whichever agent you set in the `agent` input.
- `GITHUB_TOKEN` — built-in for same-repo PRs. For cross-repo dispatch, use a GitHub App-minted or PAT token with `contents: write` + `pull-requests: write` scopes.

Set them as repo (or org) secrets — never inline them in workflow YAML.

---

## Adding a New Agent

The agent seam lives at `action/agents/<name>/`:

```
action/agents/
  claude/        # wired in v1
    install.sh   # installs the CLI on the runner
    run.sh       # reads /tmp prompt, writes /tmp output
  aider/         # scaffolded, install.sh + run.sh return "not implemented"
  codex/
  gemini/
```

Each `run.sh` receives `AGENT_API_KEY` in env and maps it to whatever variable the underlying CLI expects. Adding a new agent is a self-contained PR — drop a new folder, no changes to `action.yml`, the prompt builder, or the PR template.

---

## What to Expect

- One dispatch = one PR. No deduplication; repeated triggers produce fresh PRs.
- Empty-diff runs fail loudly — if the agent can't propose a change, the workflow fails rather than silently no-op.
- The PR is scoped to files implicated by the stack trace. The agent is instructed not to make unrelated changes.
- Every fix is reviewed and merged by a human before it reaches production.

---

## Prerequisites

- GitHub repository with Actions enabled.
- API key for the agent you're using (Anthropic, OpenAI, Google, …).
- A caller that can hand this Action a crash payload — building that caller (Crashlytics listener, webhook, etc.) is out of scope for this repo.
