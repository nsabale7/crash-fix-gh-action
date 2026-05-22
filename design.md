# Design — SP-1 Crash Auto-Fix GitHub Action

## Problem
- Fatal-crash triage is mechanical — engineers read the stack trace, find the file, write a small fix, open a PR. The investigative part is exactly what Claude Code is good at.
- Whoever holds a crash payload (Cloud Function, webhook, manual trigger) has nowhere to hand it off. There's no reusable bridge from "crash payload" to "PR with a proposed fix."

## Solution
Ship a reusable composite Action at `org/crash-fix-gh-action`. It accepts crash fields as typed inputs, checks out the caller's repo on a new branch, runs a pluggable coding-agent CLI (`claude` for v1; `aider`/`codex`/`gemini-cli` slotted in via the same seam) non-interactively against the source with the crash context, and opens a PR. The Action is invocation-agnostic — consumer workflows wire it to whichever trigger fits: `workflow_dispatch` for manual/API calls, `repository_dispatch` for external dispatchers. Crash-source plumbing stays out of this repo.

We reuse the artifacts from the prior crash-fix-agent repo (`build-prompt.sh`, `crash-payload-schema.json`, `pr-body-template.md`) — input names below mirror the existing schema so callers don't have to relearn the contract.

### Pluggable agent seam
Each agent lives under `action/agents/<name>/` with two scripts the Action invokes by convention:
- `install.sh` — installs the agent CLI on the runner (no args, no env beyond standard PATH).
- `run.sh <prompt-file> <output-file>` — reads the prompt, runs the agent non-interactively, writes the agent's text output. Receives `AGENT_API_KEY` in env and maps it to whatever env var the underlying CLI expects (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, …).

v1 ships `action/agents/claude/` fully wired. Other agents are scaffolded with placeholder scripts that exit with a "not yet implemented" error — adding one is a self-contained PR that doesn't touch `action.yml` or the prompt builder.

## Action Contract

### Inputs (`action.yml`)
Mirror the fields in `action/crash-payload-schema.json`. Action input names are kebab-case (GitHub convention); the underlying schema uses snake_case (JSON convention).

| Input (kebab) | Schema field (snake) | Required | Description |
|---|---|---|---|
| `crash-id` | `crash_id` | yes | Unique Crashlytics issue id |
| `signature` | `signature` | yes | Exception class / crash title |
| `subtitle` | `subtitle` | no | First line of stack trace summary |
| `app-version` | `app_version` | yes | App version at time of crash |
| `stack-trace` | `stack_trace` | no | Full stack trace text (may be placeholder if upstream couldn't fetch) |
| `device-info` | `device_info` | no | Device make/model + Android version |
| `occurrence-count` | `occurrence_count` | no | How many users hit this |
| `create-time` | `create_time` | yes | ISO 8601 timestamp |
| `agent` | — | no (default `claude`) | Which coding agent to invoke. Must match a folder under `action/agents/`. v1: `claude` wired; `aider`/`codex`/`gemini` scaffolded. |
| `base-branch` | — | no (default `main`) | Branch to fork from / target the PR at |
| `api-key` | — | yes (secret) | Provider API key. The selected agent's `run.sh` maps `AGENT_API_KEY` to whatever env var the underlying CLI expects. |
| `github-token` | — | yes (secret) | Used to push branch and open PR |

### Outputs
| Name | Description |
|---|---|
| `pr-url` | URL of the PR opened on the consumer repo |
| `pr-number` | Number of that PR |
| `branch` | Branch name pushed |

## Action Steps
All steps below live as `run:` blocks inside `action.yml` (composite Action). Prompt and PR-body assembly are kept in `action/*.sh` / `action/*.md` for testability; the agent's install + run are delegated to per-agent scripts so `action.yml` stays agent-agnostic.

1. **Checkout** — `actions/checkout@v4` on `base-branch` of the consumer repo.
2. **Branch** — create `crash-fix/<signature-slug>-<run-id>`.
3. **Install agent CLI** — dispatch to the selected agent's install script:
   ```yaml
   - name: Install agent CLI
     shell: bash
     run: bash action/agents/${{ inputs.agent }}/install.sh
   ```
   For `claude`, `install.sh` runs `npm install -g @anthropic-ai/claude-code` (no third-party setup action). `ubuntu-latest` runners ship Node 20+, so npm install is one line.
4. **Build prompt** — run `action/build-prompt.sh` with crash inputs in env. It scans the stack trace for implicated `.java` files, locates them in the checkout, and writes `/tmp/crash-fix-prompt.txt`.
5. **Run agent** — dispatch to the selected agent's run script:
   ```yaml
   - name: Run agent
     shell: bash
     env:
       AGENT_API_KEY: ${{ inputs.api-key }}
     run: bash action/agents/${{ inputs.agent }}/run.sh /tmp/crash-fix-prompt.txt /tmp/agent-output.txt
   ```
   For `claude`, `run.sh` exports `ANTHROPIC_API_KEY="$AGENT_API_KEY"` and invokes:
   ```bash
   claude --print --dangerously-skip-permissions < "$1" > "$2"
   ```
6. **Commit** — `git add -A && git commit -m "..."`. If no diff, fail the run loudly — no silent no-ops.
7. **Push** — push the branch using `github-token`.
8. **Open PR** — render `action/pr-body-template.md` with crash fields + the agent's output from `/tmp/agent-output.txt`, then `gh pr create`.
9. **Outputs** — export `pr-url`, `pr-number`, `branch` as step outputs.

## Trigger Wiring
Two demo workflows live in `.github/workflows/` of this repo (so we can smoke-test end-to-end) and double as templates the README points consumers at.

**`workflow_dispatch`** — typed inputs for manual / API invocation:
```yaml
on:
  workflow_dispatch:
    inputs:
      crash-id:     { required: true }
      signature:    { required: true }
      app-version:  { required: true }
      create-time:  { required: true }
      stack-trace:  { required: false }
      subtitle:     { required: false }
      device-info:  { required: false }
      agent:        { required: false, default: claude }
jobs:
  fix:
    runs-on: ubuntu-latest
    permissions: { contents: write, pull-requests: write }
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

**`repository_dispatch`** — external dispatcher pushes `client_payload` matching `action/crash-payload-schema.json`:
```yaml
on:
  repository_dispatch:
    types: [crash-detected]
jobs:
  fix:
    runs-on: ubuntu-latest
    permissions: { contents: write, pull-requests: write }
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

## Repo Layout
```
action.yml                       # composite Action definition (NEW for this repo)
action/                          # reused from crash-fix-agent
  build-prompt.sh                # assembles crash context, locates implicated files
  crash-payload-schema.json      # canonical schema for client_payload
  pr-body-template.md            # rendered into the PR body
  agents/                        # pluggable agent seam
    claude/
      install.sh                 # npm i -g @anthropic-ai/claude-code
      run.sh                     # ANTHROPIC_API_KEY=... claude --print ...
    aider/                       # scaffolded, install/run scripts exit "not implemented" in v1
      install.sh
      run.sh
    codex/                       # scaffolded
      install.sh
      run.sh
    gemini/                      # scaffolded
      install.sh
      run.sh
src/sample/                      # Android fixture the Action runs against in smoke tests
  HelloActivity.java             # known-bad source with a reproducible crash
test/fixtures/                   # sample crash payloads for repository_dispatch tests
.github/workflows/
  demo-dispatch.yml              # workflow_dispatch demo + smoke test
  demo-repository-dispatch.yml   # repository_dispatch demo + smoke test
README.md                        # adoption docs
```
`src/` is a test fixture, not source code for the Action itself — composite Actions have no compiled source. Demo workflows in this repo target `src/sample/` so the end-to-end run is self-contained. Adding a new agent in future = drop a new folder under `action/agents/` with the two scripts; no other file changes required.

## Risks / Open Questions
- **Claude Code in non-interactive Actions runners** — riskiest assumption. Need an early smoke test that the MCP loop, file edits, and process exit all behave correctly on `ubuntu-latest`.
- **Cross-agent prompt portability** — `build-prompt.sh` currently emits Claude-flavored instructions. Aider/Codex/Gemini may need format tweaks; the agent seam lets each `run.sh` post-process the prompt if needed, but a sufficiently neutral prompt is preferred. Validate when wiring the second agent.
- **Single `api-key` input** — works for one-provider-per-run. If a future agent ever needs *two* keys (e.g. an Aider config that uses Claude for edits but OpenAI for embedding), revisit the input shape.
- **Token permissions** — default `GITHUB_TOKEN` is fine for same-repo PRs. Cross-repo dispatch needs an App-minted or PAT token; README must call this out.
- **Empty-diff runs** — currently fail loudly. Alternative: open a PR with an "investigation notes" body when the agent can't propose a fix. Defer to v2.
- **Prompt-injection via crash text** — stack traces and device info are untrusted strings. The prompt builder must treat them as data, not instructions.

## Out of Scope
- Crash-source plumbing (Cloud Function, Crashlytics integration, BigQuery) — separate project.
- Deduplication across runs — every dispatch produces a fresh PR.
- Cost guardrails for agent spend — sensible defaults only.
- Self-hosted runner / Docker Action variants — `ubuntu-latest` GitHub-hosted runners only for v1.
- **Wiring non-Claude agents in v1** — `aider`/`codex`/`gemini` ship as scaffolded folders with stub scripts only. The seam exists; the implementations are follow-up work.
