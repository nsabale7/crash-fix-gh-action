# Architecture — Crash Auto-Fix GitHub Action

## System Overview

The Crash Auto-Fix GitHub Action is a reusable composite Action that automates the triage and fix-proposal workflow for fatal crashes in mobile and web applications. It accepts a crash payload (signature, stack trace, app version, and metadata), invokes a pluggable AI coding agent (Claude, Aider, Codex, or Gemini) non-interactively to investigate and propose fixes, and opens a pull request on the target repository with the generated fix.

### Core Purpose
- **Input:** Crash metadata (signature, stack trace, app version, device info, occurrence count, timestamp)
- **Processing:** Delegate to pluggable AI coding agent running non-interactively
- **Output:** PR with proposed fix, agent reasoning, and diff scoped to crash-related files

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Trigger Sources                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────┐      ┌──────────────────────┐            │
│  │  workflow_dispatch   │      │ repository_dispatch  │            │
│  │  (manual/API)        │      │ (webhook/external)   │            │
│  └──────────────┬───────┘      └──────────────┬───────┘            │
│                 │                              │                    │
│                 └──────────────────┬───────────┘                    │
│                                    │                                │
└────────────────────────────────────┼────────────────────────────────┘
                                     │
                    Typed Inputs (kebab-case)
                    - crash-id, signature, app-version, create-time
                    - stack-trace, device-info (optional)
                    - agent (default: claude)
                    - api-key, github-token (secrets)
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────┐
│              GitHub Actions Composite Action (action.yml)             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 1: Checkout target repo on base-branch                   │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 2: Create branch crash-fix/<signature-slug>-<run-id>     │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 3: Install agent CLI (action/agents/<name>/install.sh)   │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 4: Build prompt from crash data (action/build-prompt.sh) │ │
│  │ - Scan stack trace for implicated .java/.py/.js files         │ │
│  │ - Construct Markdown prompt with context                      │ │
│  │ - Write to /tmp/crash-fix-prompt.txt                          │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 5: Run agent (action/agents/<name>/run.sh)               │ │
│  │ - Map AGENT_API_KEY to provider-specific env var              │ │
│  │ - Read prompt from /tmp/crash-fix-prompt.txt                  │ │
│  │ - Invoke agent CLI non-interactively                          │ │
│  │ - Write output to /tmp/agent-output.txt                       │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│                         ┌────────────────────────────┐              │
│                         │  Agent Abstraction Seam    │              │
│                         ├────────────────────────────┤              │
│                         │ Claude (npm cli)           │              │
│                         │ Aider (pip)                │              │
│                         │ Codex (openai python)      │              │
│                         │ Gemini (gemini python)     │              │
│                         └────────────────────────────┘              │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 6: Commit changes (git add -A && git commit)              │ │
│  │ - If no diff: fail loudly                                      │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 7: Push branch (git push -u origin <branch-name>)        │ │
│  │ - Use github-token for authentication                          │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 8: Open PR                                                │ │
│  │ - Render PR body (action/pr-body-template.md)                  │ │
│  │ - Include agent output from /tmp/agent-output.txt              │ │
│  │ - Create PR via gh pr create                                   │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Step 9: Export outputs                                         │ │
│  │ - pr-url (URL of created PR)                                   │ │
│  │ - pr-number (PR #)                                             │ │
│  │ - branch (branch name)                                         │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
                                     │
                        Outputs (step.outputs.*)
                        - pr-url, pr-number, branch
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Integration Points & External Systems                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐    │
│  │ GitHub Actions  │  │  GitHub API     │  │  External AI API │    │
│  │  (runner env)   │  │  (PR creation)  │  │  (claude, aider, │    │
│  │                 │  │  (git push)     │  │   codex, gemini) │    │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘    │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. Composite Action (action.yml)
The orchestration point — defines the 9 workflow steps, input contract, and output exports.

**Responsibilities:**
- Accept 12 typed inputs (kebab-case): crash metadata, agent selector, secrets
- Coordinate 9 sequential shell steps with error handling (set -e, || exit 1)
- Export 3 outputs: pr-url, pr-number, branch
- Delegate to per-agent scripts for install and run (agent-agnostic)

**Key Properties:**
- Uses `composite` run strategy (shell scripts, no Docker)
- Minimal permissions required: `contents: write, pull-requests: write`
- Secrets passed via env, never logged

### 2. Agent Abstraction (action/agents/<name>/)
Pluggable agent seam — each AI provider gets a folder with two scripts.

**Convention:**
- `install.sh` — installs agent CLI on runner (no args, standard PATH only)
- `run.sh <prompt-file> <output-file>` — reads prompt, runs agent non-interactively, writes output

**Agents v1:**
- **Claude** (fully wired): `npm install -g @anthropic-ai/claude-code` → `claude --print --dangerously-skip-permissions`
- **Aider** (scaffolded): pip install aider → aider CLI with --no-auto-commits flag
- **Codex** (scaffolded): pip install openai → Python wrapper calling OpenAI Codex API
- **Gemini** (scaffolded): pip install google-generativeai → Python wrapper calling Google Generative AI

**Environment Variable Mapping:**
- `AGENT_API_KEY` (universal input) → provider-specific env var:
  - Claude: `ANTHROPIC_API_KEY`
  - Aider/Codex: `OPENAI_API_KEY`
  - Gemini: `GEMINI_API_KEY`

### 3. Prompt Builder (action/build-prompt.sh)
Transforms crash metadata into a structured Markdown prompt.

**Input:** Environment variables
- `CRASH_ID`, `SIGNATURE`, `SUBTITLE`, `APP_VERSION`, `STACK_TRACE`, `DEVICE_INFO`, `OCCURRENCE_COUNT`, `CREATE_TIME`

**Output:** `/tmp/crash-fix-prompt.txt`

**Logic:**
- Scan stack trace for implicated files (e.g., .java, .py, .js)
- Locate files in checked-out repo
- Construct Markdown prompt with:
  - Crash context (signature, version, device info)
  - Stack trace with line numbers
  - Implicated file snippets
  - Instructions to scope edits to crash-related files only
- Handle optional fields gracefully (omit if not provided)

### 4. PR Body Template (action/pr-body-template.md)
Markdown template for rendering PR body.

**Placeholders:**
- `{{SIGNATURE}}`, `{{CRASH_ID}}`, `{{APP_VERSION}}`
- `{{STACK_TRACE}}`, `{{DEVICE_INFO}}`, `{{AGENT_OUTPUT}}`

**Purpose:** Consistent, readable PR bodies with crash context + agent reasoning

### 5. Workflow Templates (.github/workflows/)
Demo workflows showing how to trigger the action.

**workflow_dispatch** (manual/API):
- Typed inputs for all crash fields
- Manual trigger via GitHub UI or API
- Used for testing and ad-hoc fixes

**repository_dispatch** (webhook):
- Listens for custom event (e.g., `crash-detected`)
- Unpacks `client_payload` (snake_case from schema) into action inputs (kebab-case)
- Used for integration with crash analytics platforms (Crashlytics, Sentry, Firebase)

### 6. Schema (action/crash-payload-schema.json)
JSON schema defining the canonical crash data structure.

**Fields:**
- Required: `crash_id`, `signature`, `app_version`, `create_time`
- Optional: `subtitle`, `stack_trace`, `device_info`, `occurrence_count`

**Purpose:** 
- Single source of truth for crash payload shape
- Ensures consistency between direct invocation (action inputs) and webhook dispatch (client_payload)

## Data Flow

### End-to-End Flow

```
Crash Detection Event
    │
    ├─> If workflow_dispatch trigger:
    │   └─> Manual input via GitHub UI or API
    │
    └─> If repository_dispatch trigger:
        └─> External system calls GitHub API with client_payload

        │
        ▼
    GitHub Actions Runner (ubuntu-latest)
        │
        ├─> Checkout target repo (consumer's codebase)
        │
        ├─> Derive branch name from signature + run-id
        │   (e.g., crash-fix/nullpointerexception-12345)
        │
        ├─> Install agent CLI (e.g., npm install -g @anthropic-ai/claude-code)
        │
        ├─> Build crash-fix prompt:
        │   ├─> Scan stack trace for .java/.py/.js files
        │   ├─> Extract file snippets from checked-out repo
        │   ├─> Construct Markdown with instructions
        │   └─> Write to /tmp/crash-fix-prompt.txt
        │
        ├─> Run agent non-interactively:
        │   ├─> Export AGENT_API_KEY → provider-specific env var
        │   ├─> Read prompt from /tmp/crash-fix-prompt.txt
        │   ├─> Invoke: claude --print < prompt > output.txt
        │   └─> Write to /tmp/agent-output.txt
        │
        ├─> Commit changes (if diff exists)
        │   └─> git add -A && git commit -m "fix: ..."
        │
        ├─> Push branch to origin
        │   └─> git push -u origin crash-fix/...
        │
        ├─> Open PR with rendered body:
        │   ├─> PR title: "[crash-fix] <signature>"
        │   ├─> PR body includes:
        │   │   ├─ Crash metadata (signature, version, device info)
        │   │   ├─ Stack trace
        │   │   └─ Agent output (reasoning + edits)
        │   └─> gh pr create --title "..." --body "..." --base main
        │
        └─> Export outputs (pr-url, pr-number, branch)

            │
            ▼
        PR Created on Target Repo
            │
            └─> Human review, iterate, merge
```

### Secret Handling Flow

```
User/Workflow Input
    │
    ├─> api-key (GitHub secret)
    │   └─> Passed as ${{ inputs.api-key }} → env AGENT_API_KEY
    │   └─> Mapped to provider-specific env var (ANTHROPIC_API_KEY, etc.)
    │   └─> Deleted from memory after agent run
    │
    └─> github-token (GitHub secret)
        └─> Used for git push and gh pr create
        └─> Never logged or printed
        └─> Masked in logs by GitHub Actions ::add-mask::
```

## Design Decisions

### 1. Why Composite Action vs. JavaScript Action

**Decision:** Use composite action with shell scripts.

**Rationale:**
- **Portability:** Shell scripts run on any GitHub-hosted runner (Linux, macOS, Windows WSL). JavaScript Actions require Node runtime and bundling.
- **Agent Integration:** Installing diverse agent CLIs (npm, pip, platform-specific) is simpler via shell than bundling into JavaScript.
- **Error Handling:** Shell set -e and exit codes map directly to GitHub Actions semantics; easier than JavaScript error handling.
- **Maintenance:** No build/transpile step; source is directly executable.

### 2. Why Non-Interactive CLI Invocation

**Decision:** Agents run non-interactively via `--print` flag and file I/O, not MCP loop.

**Rationale:**
- **GitHub Actions Constraint:** Runners don't allocate a TTY; commands that wait for user input hang or timeout.
- **Determinism:** File I/O (/tmp/) avoids stateful MCP connections that might persist across runs.
- **Simplicity:** `claude --print < prompt.txt > output.txt` is straightforward; MCP loop adds stateful complexity in ephemeral runner context.
- **Cost Control:** Single invocation per run; no multi-turn conversation accidental token burn.

### 3. Why PR-Based Workflow

**Decision:** Always open a PR; never auto-merge to main.

**Rationale:**
- **Human Review:** Automated fixes are fallible; humans must sanity-check diffs before merging.
- **Audit Trail:** PR comments, CI status, merge timeline create accountability record.
- **Testing:** Target repo's CI (lint, tests, etc.) runs on the PR branch; ensures fix doesn't break the build.
- **Traceability:** PR links to crash payload and agent reasoning.

### 4. Why Pluggable Agent Seam

**Decision:** Each agent gets its own install.sh and run.sh; action.yml is agent-agnostic.

**Rationale:**
- **Extensibility:** New agents can be added by dropping a folder under action/agents/<name>/ with no changes to action.yml, workflows, or docs.
- **Testing:** Each agent can be unit-tested in isolation; agent bugs don't break the Action's core.
- **Future-Proof:** Supports swapping agents without forking the Action (e.g., "try Aider for this crash type").
- **Scaffolding:** Unimplemented agents (aider, codex, gemini in v1) can ship as stubs with "not yet implemented" message; future PRs wire them without merge conflicts.

### 5. Why File-Based I/O (not env vars)

**Decision:** Prompt and output passed via /tmp/ files, not environment variables.

**Rationale:**
- **Size Limits:** Stack traces + code snippets can exceed env var limits (varies by shell, typically 1-2MB).
- **Readability:** Agent CLI tools expect files or stdin; avoiding unnecessary env-to-file conversions.
- **Compatibility:** Works with any agent CLI without custom wrappers; standard Unix pipe/redirect idiom.

### 6. Why Branch Naming: crash-fix/<signature-slug>-<run-id>

**Decision:** Branch name format includes crash signature (for human readability) and run-id (for uniqueness).

**Rationale:**
- **Readability:** Engineers scanning git log see `crash-fix/nullpointerexception-12345` and immediately understand it's a crash fix.
- **Uniqueness:** Even if the same crash triggers twice, run-id (from github.run_id) ensures distinct branches.
- **Prevention of Collisions:** If branch already exists (duplicate crash), branch creation step exits with error (no orphaned branches).
- **Slug Sanitization:** Signature is lowercased, special chars → `-`, multiple dashes collapsed.

### 7. Why Separate Prompt Builder Script

**Decision:** `action/build-prompt.sh` is a standalone script, not inlined in action.yml.

**Rationale:**
- **Testability:** Prompt logic can be unit-tested independently before running the full Action.
- **Reusability:** Future workflows (e.g., batch processing) can invoke the prompt builder without the full Action.
- **Maintainability:** Prompt format changes don't require editing action.yml.

## Extensibility Points

### Adding a New Agent

1. Create folder: `action/agents/<name>/`
2. Create `install.sh`:
   ```bash
   #!/bin/bash
   set -e
   # Install the agent CLI (npm, pip, etc.)
   # Retry logic for transient failures
   ```
3. Create `run.sh <prompt-file> <output-file>`:
   ```bash
   #!/bin/bash
   set -e
   # Map AGENT_API_KEY to provider-specific env var
   # Run agent CLI non-interactively
   # Write output to $2
   ```
4. No changes needed to action.yml, README, or workflows — just drop the folder.

### Customizing the Prompt

- Edit `action/build-prompt.sh` to change how crash context is assembled.
- Modify `action/prompt-template.md` to include additional context (e.g., recent commits, bug reports).
- Each agent's `run.sh` can post-process the prompt if needed (e.g., strip Claude-specific instructions for Aider).

### Customizing PR Body

- Edit `action/pr-body-template.md` to change the template structure.
- Add new placeholders; action.yml step 8 does the substitution.

### Customizing Triggers

- Create new workflow files in `.github/workflows/` with different event types.
- Map custom event payloads to action inputs as shown in repository_dispatch example.

## Integration Points

### 1. GitHub Actions Runner
- **What:** Ubuntu-latest (or other) runner environment
- **How:** Composite action runs shell steps; action.yml defines the interface
- **Constraints:** Non-TTY, no interactive shell, limited runtime (6 hours max per job)

### 2. GitHub API
- **What:** Pushing branch, creating PR, fetching repo content
- **How:** `git` CLI (for push), `gh` CLI (for PR creation)
- **Auth:** github-token (default GITHUB_TOKEN or custom PAT)

### 3. External AI APIs
- **What:** Claude API, OpenAI API, Google Generative AI, etc.
- **How:** Agent CLI tools (claude, openai, google-generativeai) with API keys from environment
- **Auth:** Provider-specific API key (passed as AGENT_API_KEY, mapped to provider env var)

### 4. Crash Analytics Platforms (Future)
- **What:** Crashlytics, Sentry, Firebase Crashlytics, etc.
- **How:** Repository_dispatch webhook triggered by platform when new crash detected
- **Auth:** GitHub Personal Access Token (PAT) on the platform's side to call GitHub API

## Summary

The Crash Auto-Fix Action is a **lightweight, pluggable orchestrator** that bridges crash detection systems and code repositories. By delegating to agent CLIs via a simple two-script interface, it remains agent-agnostic and extensible. The PR-based workflow ensures human oversight, while file-based I/O and non-interactive execution keep it compatible with ephemeral GitHub Actions runners. The architecture prioritizes **readability, maintainability, and extensibility** over feature completeness — v1 ships Claude wired; future agents are scaffolded and easy to add.
