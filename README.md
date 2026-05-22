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

1. Checks out your repo on a fresh `crash-fix/<signature>-<run-id>` branch (deterministic naming, global uniqueness via github.run_id).
2. Locates the source files implicated by the stack trace.
3. Runs the selected coding agent with the crash context as a prompt, letting it edit files in the workspace.
4. Commits the diff, pushes the branch, and opens a PR against your default branch.
5. PR body includes the crash signature, stack trace, app version, and the agent's change summary.

Nothing is ever pushed directly to your default branch. Every change goes through a PR for human review.

---

## Quick Start

Add one (or both) workflow(s) to your repo's `.github/workflows/`. Choose based on how you plan to trigger the action.

### Option 1: `workflow_dispatch` — manual or API-triggered

Copy `.github/workflows/crash-auto-fix-manual.yml`:

```yaml
name: Crash auto-fix (manual)

on:
  workflow_dispatch:
    inputs:
      crash-id:
        description: Unique crash issue id
        required: true
        type: string
      signature:
        description: Exception class / crash title
        required: true
        type: string
      subtitle:
        description: First line of stack trace summary
        required: false
        type: string
      app-version:
        description: App version at time of crash
        required: true
        type: string
      stack-trace:
        description: Full stack trace text
        required: false
        type: string
      device-info:
        description: Device make/model + OS version
        required: false
        type: string
      occurrence-count:
        description: Number of users hit
        required: false
        type: number
      create-time:
        description: ISO 8601 timestamp
        required: true
        type: string
      agent:
        description: Coding agent to invoke (claude, aider, codex, gemini)
        required: false
        type: string
        default: claude
      base-branch:
        description: Branch to fork from and target the PR at
        required: false
        type: string
        default: main
      api-key:
        description: Provider API key (masked)
        required: true
        type: string
      github-token:
        description: GitHub token for pushing branch and opening PR (masked)
        required: true
        type: string

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    outputs:
      pr-url: ${{ steps.action.outputs.pr-url }}
      pr-number: ${{ steps.action.outputs.pr-number }}
      branch: ${{ steps.action.outputs.branch }}
    steps:
      - name: Run crash-fix action
        id: action
        uses: ./
        with:
          crash-id: ${{ inputs.crash-id }}
          signature: ${{ inputs.signature }}
          subtitle: ${{ inputs.subtitle }}
          app-version: ${{ inputs.app-version }}
          stack-trace: ${{ inputs.stack-trace }}
          device-info: ${{ inputs.device-info }}
          occurrence-count: ${{ inputs.occurrence-count }}
          create-time: ${{ inputs.create-time }}
          agent: ${{ inputs.agent }}
          base-branch: ${{ inputs.base-branch }}
          api-key: ${{ inputs.api-key }}
          github-token: ${{ inputs.github-token }}
```

**Trigger via GitHub UI:**
1. Go to Actions → "Crash auto-fix (manual)"
2. Click "Run workflow"
3. Fill in required fields (crash-id, signature, app-version, create-time)
4. Click "Run workflow"

**Trigger via GitHub CLI:**

```bash
gh workflow run crash-auto-fix-manual.yml \
  -f crash-id=abc123 \
  -f signature=NullPointerException \
  -f app-version=1.2.3 \
  -f create-time=2026-05-18T12:00:00Z \
  -f stack-trace="$(cat trace.txt)" \
  -f api-key="$ANTHROPIC_API_KEY" \
  -f github-token="$GITHUB_TOKEN"
```

**Trigger via REST API:**

```bash
curl -X POST https://api.github.com/repos/<owner>/<repo>/actions/workflows/crash-auto-fix-manual.yml/dispatches \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d '{
    "ref": "main",
    "inputs": {
      "crash-id": "abc123",
      "signature": "NullPointerException",
      "app-version": "1.2.3",
      "create-time": "2026-05-18T12:00:00Z",
      "stack-trace": "java.lang.NullPointerException\n\tat com.example.MainActivity.onCreate(MainActivity.java:42)",
      "api-key": "sk-ant-...",
      "github-token": "ghp_..."
    }
  }'
```

### Option 2: `repository_dispatch` — external dispatcher (webhook, Cloud Function, etc.)

Copy `.github/workflows/crash-auto-fix-dispatch.yml`:

```yaml
name: Crash auto-fix (repository_dispatch)

on:
  repository_dispatch:
    types:
      - crash-detected

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    outputs:
      pr-url: ${{ steps.action.outputs.pr-url }}
      pr-number: ${{ steps.action.outputs.pr-number }}
      branch: ${{ steps.action.outputs.branch }}
    steps:
      - name: Run crash-fix action from repository_dispatch payload
        id: action
        uses: ./
        with:
          # Map client_payload fields (snake_case) to action inputs (kebab-case)
          # Required fields from payload
          crash-id: ${{ github.event.client_payload.crash_id }}
          signature: ${{ github.event.client_payload.signature }}
          app-version: ${{ github.event.client_payload.app_version }}
          create-time: ${{ github.event.client_payload.create_time }}

          # Optional fields from payload
          subtitle: ${{ github.event.client_payload.subtitle }}
          stack-trace: ${{ github.event.client_payload.stack_trace }}
          device-info: ${{ github.event.client_payload.device_info }}
          occurrence-count: ${{ github.event.client_payload.occurrence_count }}

          # Conditional defaults
          # agent defaults to 'claude' if not provided in payload
          agent: ${{ github.event.client_payload.agent || 'claude' }}

          # base-branch defaults to 'main' if not provided
          base-branch: ${{ github.event.client_payload.base_branch || 'main' }}

          # API key and GitHub token (typically from secrets in the calling repo)
          api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ github.token }}
```

**Trigger via GitHub CLI:**

```bash
gh repo dispatch crash-detected \
  --client-payload '{
    "crash_id": "abc123",
    "signature": "NullPointerException",
    "app_version": "1.2.3",
    "create_time": "2026-05-18T12:00:00Z",
    "stack_trace": "java.lang.NullPointerException...",
    "device_info": "Pixel 7 / Android 14",
    "occurrence_count": 42,
    "agent": "claude"
  }'
```

**Trigger via REST API (cURL):**

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
      "stack_trace": "java.lang.NullPointerException\n\tat com.example.MainActivity.onCreate(MainActivity.java:42)",
      "device_info": "Pixel 7 / Android 14",
      "occurrence_count": 42,
      "agent": "claude"
    }
  }'
```

**Payload Validation:**
`client_payload` must conform to [`action/crash-payload-schema.json`](action/crash-payload-schema.json). See the schema for the complete type definitions of all fields.

---

## Required Inputs

Three inputs are **mandatory security inputs** that must be passed via the `with:` block from GitHub Secrets. A common mistake is setting them as environment variables — this prevents the action from receiving them and causes auth failures.

### The Three Required Security Inputs

| Input | How to pass it | Secret name |
|---|---|---|
| `api-key` | `with: api-key: ${{ secrets.ANTHROPIC_API_KEY }}` | `ANTHROPIC_API_KEY` |
| `github-token` | `with: github-token: ${{ secrets.GITHUB_TOKEN }}` | Built-in `GITHUB_TOKEN` |
| `create-time` | `with: create-time: <ISO 8601 timestamp>` | N/A (crash payload field) |

### WRONG — do not do this

```yaml
steps:
  - uses: nsabale7/crash-fix-gh-action@main
    with:
      crash-id: abc123
      signature: NullPointerException
      app-version: 1.0.0
      # ❌ create-time is missing entirely
      # ❌ api-key is missing from with: block
      # ❌ github-token is missing from with: block
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}  # ❌ wrong — must be an input, not env var
```

Setting `ANTHROPIC_API_KEY` as an environment variable does **not** satisfy the `api-key` input. The action reads `api-key` from the `with:` block and maps it to the correct env var internally. If you pass it as `env:`, the action will fail with "Error: Input 'api-key' is required but was not provided."

### CORRECT — do this instead

```yaml
steps:
  - uses: nsabale7/crash-fix-gh-action@main
    with:
      crash-id: abc123
      signature: NullPointerException
      app-version: 1.0.0
      create-time: "2026-05-19T10:00:00Z"   # ✅ required ISO 8601 timestamp
      api-key: ${{ secrets.ANTHROPIC_API_KEY }}   # ✅ passed as with: input from secret
      github-token: ${{ secrets.GITHUB_TOKEN }}   # ✅ passed as with: input
```

### Minimal correct workflow

```yaml
name: Crash auto-fix

on:
  workflow_dispatch:
    inputs:
      crash-id:    { required: true }
      signature:   { required: true }
      app-version: { required: true }
      create-time: { required: true }

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: nsabale7/crash-fix-gh-action@main
        with:
          crash-id:     ${{ inputs.crash-id }}
          signature:    ${{ inputs.signature }}
          app-version:  ${{ inputs.app-version }}
          create-time:  ${{ inputs.create-time }}
          api-key:      ${{ secrets.ANTHROPIC_API_KEY }}   # ✅ from secrets, passed as input
          github-token: ${{ secrets.GITHUB_TOKEN }}         # ✅ built-in token, passed as input
```

> **Key rule:** `api-key` and `github-token` MUST be passed as `with:` inputs. Setting them as `env:` variables will not work and will cause the action to fail.

---

## Inputs

| Input | Required | Default | Type | Description | Example |
|---|---|---|---|---|---|
| `crash-id` | **yes** | — | string | Unique Crashlytics issue id | `123e4567-e89b-12d3-a456-426614174000` |
| `signature` | **yes** | — | string | Exception class / crash title | `java.lang.NullPointerException` |
| `app-version` | **yes** | — | string | App version at time of crash | `1.2.3` or `2026.05.19-alpha` |
| `create-time` | **yes** | — | string (ISO 8601) | Timestamp of crash | `2026-05-18T12:00:00Z` |
| `stack-trace` | no | — | string | Full stack trace text (multiline) | `java.lang.NullPointerException: ...\nat com.example.MainActivity...` |
| `subtitle` | no | — | string | First line of stack trace | `NullPointerException in MainActivity.onCreate` |
| `device-info` | no | — | string | Device make/model + OS version | `Pixel 7 / Android 14` |
| `occurrence-count` | no | — | integer | Number of users affected | `42` |
| `agent` | no | `claude` | string | Coding agent to invoke. Wired in v1: `claude`. Scaffolded: `aider`, `codex`, `gemini`. | `claude` |
| `base-branch` | no | `main` | string | Branch to fork from and target the PR at | `main` or `develop` |
| `api-key` | **yes** (secret) | — | string (secret) | Provider API key. Env mapping: `ANTHROPIC_API_KEY` (Claude), `OPENAI_API_KEY` (Aider/Codex), `GEMINI_API_KEY` (Gemini). Never hardcode in workflows — use GitHub Secrets. | `sk-ant-...` |
| `github-token` | **yes** (secret) | — | string (secret) | GitHub token for pushing branches and opening PRs. Use `${{ secrets.GITHUB_TOKEN }}` for same-repo, or a GitHub App token for cross-repo. Requires `contents: write` + `pull-requests: write` scopes. | `ghp_...` |

### Required vs. Optional

**Always required (4 fields):**
- `crash-id` — used to link PR to crash reporting system
- `signature` — used as PR title prefix and commit message
- `app-version` — included in PR body
- `create-time` — included in PR body
- `api-key` — agent invocation depends on it
- `github-token` — PR creation and push depend on it

**Optional (8 fields):**
- `stack-trace`, `subtitle`, `device-info`, `occurrence-count` — included in PR body if provided; omitted if missing
- `agent` — defaults to `claude`
- `base-branch` — defaults to `main`

## Outputs

| Output | Description | Example |
|---|---|---|
| `pr-url` | Full URL of the PR opened | `https://github.com/owner/repo/pull/42` |
| `pr-number` | PR number (GitHub assigns on creation) | `42` |
| `branch` | Branch name created and pushed | `crash-fix/nullpointerexception-1234567890` |

**Accessing outputs in a workflow:**

```yaml
- name: Run crash-fix action
  id: action
  uses: ./
  with:
    # ... inputs ...
    
- name: Print results
  run: |
    echo "PR created: ${{ steps.action.outputs.pr-url }}"
    echo "PR number: ${{ steps.action.outputs.pr-number }}"
    echo "Branch: ${{ steps.action.outputs.branch }}"
```

**Forwarding outputs from a wrapper workflow:**

```yaml
jobs:
  fix:
    outputs:
      pr-url: ${{ steps.action.outputs.pr-url }}
      pr-number: ${{ steps.action.outputs.pr-number }}
      branch: ${{ steps.action.outputs.branch }}
    steps:
      - uses: ./
        id: action
        # ...
```

---

## Secrets & Security

### Setting Up Secrets

Set these as **repository secrets** (Settings → Secrets and variables → Actions → New repository secret). Never inline them in workflow YAML files.

- **`AGENT_API_KEY`**  
  API key for the agent you're using:
  - Claude: `ANTHROPIC_API_KEY` (sk-ant-...)
  - Aider/Codex: `OPENAI_API_KEY` (sk-...)
  - Gemini: `GEMINI_API_KEY` (AIza...)  
  This secret is passed to the agent process via `$AGENT_API_KEY` env var and never logged.

- **`GITHUB_TOKEN`** (if using `repository_dispatch`)  
  Use `${{ secrets.GITHUB_TOKEN }}` for same-repo PRs (built-in, no setup required).  
  For cross-repo triggers, create a GitHub App or PAT with minimal scopes:
  - `contents: write` — push branches
  - `pull-requests: write` — open PRs  
  Never use `repo` scope (full read/write on all repos).

### Security Best Practices

1. **Secrets are masked in logs** — GitHub automatically redacts values matching `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, and token patterns (ghp_, sk-) from workflow logs. The CI pipeline includes an extra log-scan step that fails if any unmasked secrets are detected.

2. **No secret leakage in PR bodies** — The action never includes API keys, tokens, or other credentials in PR bodies, commit messages, or file diffs.

3. **Tight GitHub permissions** — Workflows declare minimal permissions:
   ```yaml
   permissions:
     contents: write        # can push branches
     pull-requests: write   # can open/update PRs
   ```
   No delete, admin, or repo-wide write access.

4. **Input validation** — All inputs are sanitized before use in shell commands. The action fails loudly on malformed inputs (e.g., shell metacharacters in crash-id).

5. **Error messages are safe** — If the agent or action fails, error output does not include env vars, API keys, or stack traces.

---

## Adding a New Agent

Agents are pluggable via the `action/agents/<name>/` directory structure. Adding a new agent requires no changes to `action.yml` or the core workflow.

### Agent Directory Structure

```
action/agents/
├── claude/        # implemented in v1
│   ├── install.sh # installs Claude Code CLI
│   └── run.sh     # invokes claude with prompt file
├── aider/         # scaffolded (returns "not yet implemented")
│   ├── install.sh
│   └── run.sh
├── codex/
│   ├── install.sh
│   └── run.sh
└── gemini/
    ├── install.sh
    └── run.sh
```

### How It Works

1. **Install phase** (`action/agents/<name>/install.sh`):
   - Install the agent CLI on the GitHub Actions runner
   - Examples: `npm install -g @anthropic-ai/claude-code`, `pip install aider-chat`
   - Should exit 0 on success, 1 on failure
   - May be run multiple times (idempotent)

2. **Run phase** (`action/agents/<name>/run.sh`):
   - Invoked with two arguments: input prompt file, output file
   - Example call: `bash action/agents/claude/run.sh /tmp/crash-fix-prompt.txt /tmp/agent-output.txt`
   - **Environment variables provided:**
     - `AGENT_API_KEY` — the API key from the `api-key` input (secret)
     - `GITHUB_WORKSPACE` — the repo root (current working directory)
   - **Expected behavior:**
     - Read the prompt from `$1` (first argument)
     - Invoke the agent CLI (e.g., `claude --print < $1 > $2`)
     - Write a text summary of changes to `$2` (second argument)
     - Exit 0 on success, 1 on failure (workflow fails if exit code is 1)
     - Agent should NOT commit or push changes; the action handles that
     - Agent modifies files in place in `$GITHUB_WORKSPACE`

3. **Prompt format:**
   - Plain text Markdown generated by `action/build-prompt.sh`
   - Includes crash signature, stack trace, app version, device info, and instructions
   - Agent should read and understand the prompt without additional parsing

### Example: Adding Aider

Create `action/agents/aider/install.sh`:

```bash
#!/bin/bash
set -e

# Install aider from PyPI
pip install aider-chat

echo "aider installed successfully"
```

Create `action/agents/aider/run.sh`:

```bash
#!/bin/bash
set -e

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Validate arguments
if [[ -z "$INPUT_FILE" ]] || [[ -z "$OUTPUT_FILE" ]]; then
    echo "Usage: run.sh <input-prompt-file> <output-summary-file>"
    exit 1
fi

# Map AGENT_API_KEY to OPENAI_API_KEY (aider expects this)
export OPENAI_API_KEY="$AGENT_API_KEY"

# Run aider non-interactively
PROMPT=$(cat "$INPUT_FILE")
aider --yes-always --no-auto-commits <<EOF > "$OUTPUT_FILE" 2>&1
$PROMPT
EOF

echo "aider completed successfully. Summary written to $OUTPUT_FILE"
```

### Example: Adding Gemini

Create `action/agents/gemini/install.sh`:

```bash
#!/bin/bash
set -e

# Install Google Generative AI CLI (hypothetical)
pip install google-generativeai

echo "Gemini CLI installed successfully"
```

Create `action/agents/gemini/run.sh`:

```bash
#!/bin/bash
set -e

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [[ -z "$INPUT_FILE" ]] || [[ -z "$OUTPUT_FILE" ]]; then
    echo "Usage: run.sh <input-prompt-file> <output-summary-file>"
    exit 1
fi

# Map AGENT_API_KEY to GEMINI_API_KEY
export GEMINI_API_KEY="$AGENT_API_KEY"

# Invoke Gemini with the prompt
python3 -c "
import sys
from google.generativeai import genai
genai.configure(api_key='$GEMINI_API_KEY')
prompt = open('$INPUT_FILE').read()
response = genai.GenerativeModel('gemini-pro').generate_content(prompt)
with open('$OUTPUT_FILE', 'w') as f:
    f.write(response.text)
" 2>&1

echo "Gemini completed successfully. Summary written to $OUTPUT_FILE"
```

### Testing a New Agent Locally

```bash
# Set up the agent
bash action/agents/my-agent/install.sh

# Run it
AGENT_API_KEY="sk-..." bash action/agents/my-agent/run.sh \
    test/fixtures/sample-prompt.txt \
    /tmp/output.txt

# Check the output
cat /tmp/output.txt
```

---

## Troubleshooting

### Workflow fails immediately with "Agent not found"

**Symptom:** `Error: action/agents/claude/install.sh: No such file or directory`

**Solution:** Verify the agent folder exists and `install.sh` is executable:
```bash
ls -la action/agents/claude/
chmod +x action/agents/claude/install.sh action/agents/claude/run.sh
```

### Workflow fails with "AGENT_API_KEY not set" or "Unauthorized"

**Symptom:** Agent CLI fails with an auth error.

**Solution:**
1. Verify the secret is set: Settings → Secrets and variables → Actions → `AGENT_API_KEY` should be listed.
2. Verify the key is valid for the agent:
   - Claude: Must start with `sk-ant-`
   - OpenAI/Aider: Must start with `sk-`
   - Gemini: Must start with `AIza`
3. Verify the key is passed correctly in the workflow YAML:
   ```yaml
   api-key: ${{ secrets.AGENT_API_KEY }}
   ```

### PR body shows "{{PLACEHOLDER}}" instead of actual values

**Symptom:** PR description contains literal `{{SIGNATURE}}`, `{{CRASH_ID}}`, etc.

**Solution:** This indicates a substitution failure. Check:
1. `action/pr-body-template.md` exists and contains placeholders
2. Env vars are exported correctly in the "Open PR" step of `action.yml`
3. Run workflow in debug mode: re-run with "Enable debug logging" checked in GitHub Actions

### "No changes detected" failure

**Symptom:** Workflow reaches "Commit changes" step and exits with "No changes detected. Failing run."

**Solution:** The agent ran successfully but did not modify any files. This is intentional — the action fails loudly if there's no diff, to avoid silent no-ops. Causes:
1. **Agent doesn't understand the crash context** — Review the prompt and stack trace for clarity.
2. **Stack trace doesn't implicate any files** — Ensure `stack-trace` is provided and includes file paths.
3. **Agent is not authorized** — Check the API key and agent CLI logs (set `ACTIONS_STEP_DEBUG=true` in secrets for verbose output).

### Duplicate PRs on repeated triggers

**Symptom:** Running the same crash fix multiple times creates multiple PRs instead of updating the existing one.

**Solution:** This is by design — the action creates a new PR for each trigger. If you want to consolidate, manually close duplicate PRs and keep the first one. (Deduplication could be added as a future feature.)

### Cross-repo dispatch fails with permission error

**Symptom:** `GITHUB_TOKEN` error when running from a caller repo to a target repo.

**Solution:** The caller repo's `GITHUB_TOKEN` doesn't have access to the target repo. Use a GitHub App or PAT instead:
1. Create a GitHub App with `contents: write` + `pull-requests: write` scopes
2. Generate a token via the App
3. Set it as a secret in the caller repo (or pass as `api-key`)

---

## FAQ

### How do I use this action in my own workflows?

**See Quick Start above.** You can either:
- Copy `.github/workflows/crash-auto-fix-manual.yml` and use `workflow_dispatch` for manual triggers
- Copy `.github/workflows/crash-auto-fix-dispatch.yml` and use `repository_dispatch` for webhook integration
- Create your own workflow that calls `uses: owner/crash-fix-gh-action@v1` and passes inputs

### How do I add a new agent (Aider, Codex, Gemini)?

**See "Adding a New Agent" section above.** TL;DR: Create `action/agents/<name>/install.sh` and `action/agents/<name>/run.sh` in a PR; no changes to `action.yml` needed.

### How do I customize the prompt the agent receives?

Edit `action/prompt-template.md` (template structure) or `action/build-prompt.sh` (prompt generation logic). Changes are picked up automatically — no action.yml changes needed.

### How do I change the PR title or body?

Edit `action/pr-body-template.md` (the body template). The PR title is set in `action.yml` step "Open PR"; modify the `--title` argument.

### Can I run this action on a different branch than `main`?

Yes, set the `base-branch` input (defaults to `main`). Example:
```yaml
- uses: ./
  with:
    base-branch: develop
```
The action will check out `develop`, create a new branch from it, and open a PR against `develop`.

### What if the agent output is very long?

The output is truncated to 5000 characters when included in the PR body (this limit is set in the "Open PR" step). To change it, edit `action.yml`'s substitution logic.

### Can I trigger this from a Crashlytics webhook?

Yes! Wire a Cloud Function (Google Cloud) or Lambda (AWS) to listen for Crashlytics webhooks, parse the crash payload, and call `gh repo dispatch` or the REST API. See the `repository_dispatch` examples above for the payload format.

### How do I validate my crash payload before triggering?

Use the JSON Schema at `action/crash-payload-schema.json`. Example:
```bash
# Validate with ajv-cli
npx ajv validate -s action/crash-payload-schema.json -d payload.json
```

### What happens if my repo's default branch is not `main`?

Pass `base-branch: <your-default-branch>` to the action. Example:
```yaml
base-branch: master  # if your default is 'master'
```

---

## What to Expect

- **One dispatch = one PR.** No deduplication; repeated triggers produce fresh PRs. (Deduplication could be added as a future feature.)
- **Empty-diff runs fail loudly.** If the agent can't propose a change, the workflow fails with "No changes detected" rather than silently no-op.
- **The PR is scoped to files implicated by the stack trace.** The agent is instructed to focus on the crash-related code and avoid unrelated changes.
- **Every fix is reviewed and merged by a human.** The action never pushes directly to your default branch; all changes go through PRs.
- **Secrets are never logged.** GitHub Actions masks secret values in logs; the action includes an extra log-scan step to catch any leaks.

---

## Prerequisites

- **GitHub repository** with Actions enabled
- **API key** for the agent you're using:
  - Claude: [Anthropic console](https://console.anthropic.com)
  - OpenAI (Aider/Codex): [OpenAI API keys](https://platform.openai.com/account/api-keys)
  - Google (Gemini): [Google AI Studio](https://ai.google.dev/)
- **A source of crash payloads** — your own webhook, Crashlytics listener, Cloud Function, etc. (building that caller is out of scope for this repo)
