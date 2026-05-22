# SP-1 Crash Auto-Fix GitHub Action — Implementation Plan

> A reusable composite GitHub Action that accepts crash payloads (signature, stack trace, app version), invokes Claude Code CLI non-interactively to investigate and fix the crash, and opens a PR with the fix. v1 ships Claude wired; aider/codex/gemini scaffolded.

---

## Tasks

### Phase 1: Foundation & Agent Wiring

#### Task 1: Repository Setup, CI Workflow & Claude Agent Integration
- **Change:** Initialize repository structure, create action.yml skeleton, create .github/workflows/ci.yml for lint + unit tests, scaffold action/agents/, implement action/agents/claude/{install.sh,run.sh} with end-to-end Claude CLI wiring, add secret-masking and log-scan CI jobs.
- **Files:** 
  - action.yml (composite action definition)
  - action/agents/claude/install.sh (npm install -g @anthropic-ai/claude-code, with retry logic: max 3 retries on transient errors)
  - action/agents/claude/run.sh (run claude --print --dangerously-skip-permissions non-interactively)
  - action/agents/{aider,codex,gemini}/install.sh + run.sh (stubbed with "not yet implemented")
  - action/crash-payload-schema.json (typed input schema)
  - .github/workflows/ci.yml (runs actionlint on all .github/workflows/*.yml, runs BATS test suite, masks ANTHROPIC_API_KEY and AGENT_API_KEY in logs, includes log-scan step that greps for secret prefixes: sk-ant-, sk-, ghp_, ANTHROPIC_API_KEY)
  - .gitignore, README.md stub
- **Tier:** standard
- **Done when:** 
  - action.yml is valid (syntax check via `gh action validate` or equiv)
  - .github/workflows/ci.yml is valid YAML and triggers on push to all branches
  - ci.yml secret-masking step masks ANTHROPIC_API_KEY and AGENT_API_KEY before logs are captured
  - ci.yml log-scan step greps for secret prefixes (sk-ant-, ghp_) and fails if found; includes a test case with intentional secret leak to verify detection
  - Claude install.sh includes retry logic (max 3 retries with exponential backoff) on transient network failures; done criterion: install.sh succeeds on first attempt, and succeeds after one simulated transient failure + retry
  - Claude run.sh accepts a prompt file and writes output in non-TTY mode
  - **Riskiest assumption validated:** Smoke test in headless environment (non-TTY, no $TERM set) confirms Claude Code CLI accepts non-interactive input/output (specifically, `claude --print < input.txt > output.txt` in a GitHub Actions runner or local `act` sandbox) without hanging, requiring TTY, or prompting for auth. Output file is non-empty and contains the agent's response.
  - Scaffolded agent folders exist with stub scripts that exit cleanly with "not yet implemented" message
  - ci.yml pipeline is green (actionlint passes, BATS tests pass, secret-scan passes)
- **Blockers:** 
  - RISKIEST: Claude Code CLI must run non-interactively in GitHub Actions context. If it hangs waiting for auth or MCP server state, sprint fails. Validated via explicit smoke test (non-TTY invocation).
  - npm install -g may fail if Node version < 16 on runner — verify ubuntu-latest has Node 20+

#### Task 2: Action Scaffolding & Input Handling
- **Change:** Implement action.yml input/output contract, add action/build-prompt.sh to construct crash prompt from inputs, create action/pr-body-template.md for PR body rendering.
- **Files:**
  - action.yml (complete with all inputs from spec, typed, with descriptions)
  - action/build-prompt.sh (read CRASH_SIGNATURE, STACK_TRACE, APP_VERSION, etc from env; scan stack trace for .java files; construct prompt; write /tmp/crash-fix-prompt.txt)
  - action/pr-body-template.md (template with placeholders for crash fields + agent output)
  - action/prompt-template.md (example prompt structure: Markdown format, includes all provided fields, omits optional fields if absent, instructs agent to limit edits to crash-related files)
  - Test files: test/fixtures/sample-crash-*.json (realistic crash payloads for testing)
- **Tier:** standard
- **Done when:**
  - action.yml passes schema validation
  - action/build-prompt.sh outputs a well-formed prompt when fed sample crash inputs
  - Prompt format defined: all provided fields included in Markdown; optional fields (stack-trace, device-info, etc.) omitted if not provided; prompt is human-readable and clearly instructs agent to scope changes to crash-related files only
  - PR template renders without errors (no undefined placeholders)
  - Input names match the spec (kebab-case, map to schema snake_case fields)
- **Blockers:** None identified

#### Task 3: Composite Action Workflow
- **Change:** Implement the full workflow in action.yml: checkout → branch creation → agent install → build prompt → run agent → commit → push → open PR. Each step is a shell run: block.
- **Files:**
  - action.yml (complete with all workflow steps as documented in design.md section "Action Steps 1-9")
  - test/bats/claude-invocation.bats (BATS test verifying exact invocation: `claude --print < /tmp/crash-fix-prompt.txt > /tmp/agent-output.txt` in non-TTY environment succeeds and produces non-empty output)
- **Tier:** standard
- **Done when:**
  - All 9 steps from design.md are implemented as run: blocks in action.yml
  - Each step has error handling (set -e, || exit 1)
  - Step outputs (pr-url, pr-number, branch) are exported correctly
  - Syntax is valid YAML
  - BATS test confirms non-TTY invocation pattern works (run via `act -l` or local GitHub Actions runner simulation)
- **Blockers:** None identified

#### VERIFY: Foundation
- Dry-run the composite action on ubuntu-latest with sample crash input (workflow_dispatch manually or gh act locally if available)
- Confirm: checkout succeeds, branch created, Claude CLI installed, prompt generated, agent ran, commit made, push succeeded, PR opened
- Report: success/failure, PR URL if successful, any blockers

---

### Phase 2: Demo Workflows & Integration

#### Task 4: workflow_dispatch Trigger Template
- **Change:** Add .github/workflows/crash-fix-manual.yml demonstrating workflow_dispatch trigger with typed inputs, wired to the composite action.
- **Files:** .github/workflows/crash-fix-manual.yml
- **Tier:** cheap
- **Done when:**
  - Workflow is valid YAML
  - Inputs match action contract (crash-id, signature, app-version, stack-trace, agent, api-key, github-token)
  - On manual trigger, calls the composite action with correct input mapping
  - README will point users to this as the template for their own workflows
- **Blockers:** None

#### Task 5: repository_dispatch Trigger Template & Branch Naming
- **Change:** Add .github/workflows/crash-fix-webhook.yml demonstrating repository_dispatch trigger, unpacking crash fields from client_payload into action inputs. Clarify branch naming logic.
- **Files:** .github/workflows/crash-fix-webhook.yml
- **Tier:** cheap
- **Done when:**
  - Workflow is valid YAML
  - Listens for custom event type (e.g., crash-detected)
  - Maps client_payload fields (snake_case from schema) to action inputs (kebab-case)
  - Defaults agent to 'claude' if not provided
  - Branch name format `crash-fix/<signature-slug>-<run-id>` is implemented; run-id is derived from github.run_id (deterministic, globally unique per workflow run)
  - If branch already exists (e.g., duplicate crash), branch.sh exits gracefully with clear error message (exit 1); no orphaned branch is created
- **Blockers:** None

#### Task 6: Documentation — README
- **Change:** Write comprehensive README covering: what the Action does, how to use it, inputs/outputs reference, required secrets, example workflows (both triggers), instructions for adding a new agent, troubleshooting.
- **Files:** README.md
- **Tier:** cheap
- **Done when:**
  - README includes the spec from requirements.md (Goal section)
  - Inputs, outputs tables with descriptions
  - Required secrets listed (AGENT_API_KEY, GITHUB_TOKEN) with scopes
  - Example workflows (workflow_dispatch and repository_dispatch) with clear callouts
  - "Adding a new agent" section explains the `action/agents/<name>/` convention and script interface (install.sh, run.sh)
  - No sensitive data in examples (redacted tokens shown)
- **Blockers:** None

#### VERIFY: Integration
- Manually trigger workflow_dispatch with sample crash fields on main branch
- Confirm: PR created, title/body contain crash signature + fix summary, diff is scoped to affected files
- Manually trigger repository_dispatch via gh cli or curl with sample client_payload
- Confirm: same result as workflow_dispatch
- Report: both workflows successful, PR URLs, any issues

---

### Phase 3: Security & Hardening

#### Task 7: Security & Secrets Audit
- **Change:** Review action.yml for security: secrets are passed via env (not logged), no hardcoded credentials, permissions are minimal, error messages don't leak sensitive data. Add guardrails for malformed inputs.
- **Files:** action.yml, action/*.sh
- **Tier:** premium
- **Done when:**
  - Secrets (AGENT_API_KEY, github-token) are only passed via env, never logged or printed
  - Error messages don't leak stack traces or env var values
  - Input validation: crash-id, signature, app-version are required; others optional but parsed safely (no injection vectors)
  - PR body and commit messages don't include raw API keys or tokens
  - No shell injection vulnerabilities (inputs are quoted, env vars safe)
  - GitHub Actions secret-masking is applied (ANTHROPIC_API_KEY pattern added to .github/workflows/ci.yml)
  - Post-run log-scan (grep -E for patterns: sk-ant-, ghp_, ANTHROPIC_API_KEY) fails the job if any match found
  - GitHub-hosted runner permissions are minimal (contents: write, pull-requests: write)
- **Blockers:** 
  - If claude CLI outputs secrets or stack traces when it fails, task may escalate to premium review

#### Task 8: Scaffolded Agents (aider, codex, gemini)
- **Change:** Each scaffolded agent folder contains install.sh and run.sh that exit cleanly with "agent X not yet implemented" message. Future PRs will wire the actual agents without touching action.yml.
- **Files:** action/agents/{aider,codex,gemini}/{install.sh,run.sh}
- **Tier:** cheap
- **Done when:**
  - Each agent folder exists under action/agents/
  - install.sh exits 1 with message "aider agent is not yet implemented"
  - run.sh exits 1 with message "aider agent is not yet implemented"
  - Same for codex, gemini
  - Selecting one of these agents in the action invocation results in a clean, informative failure (not a confusing "folder not found" error)
- **Blockers:** None

#### VERIFY: Security & Scaffolding
- Run security-focused review: check for credential leaks, injection vectors, permissions.
- Attempt to invoke the action with agent: aider → confirm clean "not yet implemented" failure
- Attempt to invoke with malformed crash-id (e.g., URL, shell metacharacters) → confirm safe handling
- Report: security audit pass/fail, scaffolding status

---

### Phase 4: Documentation Harvest

#### Task 8.5 (Added): E2E Test Repository Setup
- **Change:** Create and configure the dedicated test repository `crash-fix-e2e-target` (or use an existing test app if available). Provision ANTHROPIC_API_KEY as a GitHub secret in that repo. Install demo workflows (crash-fix-manual.yml and crash-fix-webhook.yml) from this repo into .github/workflows/ of the test repo.
- **Files:** (external, on test repo)
  - Ensure test repo has: GitHub Actions enabled, secret `ANTHROPIC_API_KEY` set, test workflows installed
  - Ensure test app has: at least one known crash signature (e.g., a NullPointerException in a specific file) so that T-7 can trigger a fix and verify the output
- **Tier:** cheap
- **Done when:**
  - Test repo exists and is accessible (https://github.com/org/crash-fix-e2e-target or similar)
  - ANTHROPIC_API_KEY secret is set in test repo settings
  - Demo workflows are present in .github/workflows/
  - Test app compiles and is runnable (no build errors)
  - Test crash is reproducible and documented (e.g., "NullPointerException in MainActivity line 42")
- **Blockers:** Access to test repo creation; must be done before T-7 runs

#### Task 9: Architecture & Design Documentation
- **Change:** Extract durable knowledge from requirements.md, design.md, and PLAN.md into docs/: write docs/architecture.md covering the pluggable agent seam, the Action input contract, the workflow triggers, and why certain design choices (composite Action, non-interactive CLI, PR-based workflow) were made. Include diagrams or ASCII art if helpful.
- **Files:** docs/architecture.md, docs/adding-agents.md (extracted from README section)
- **Tier:** standard
- **Done when:**
  - docs/architecture.md exists and covers: why composite Action, how the agent seam works, how inputs flow through the system, why workflows dispatch to the Action (not direct invocation)
  - docs/adding-agents.md is a standalone guide for future contributors (extract and expand README's "Adding a new agent" section)
  - No task-level or debug notes (those stay in PLAN.md and progress.json)
  - Captures design trade-offs (e.g., "we chose non-interactive mode to avoid GitHub Actions timeout issues, at the cost of limited interactivity during debugging")
- **Blockers:** None

#### VERIFY: Docs Harvest
- Reviewer checks: are the docs captured durable knowledge (architecture, design decisions)? Do they help a new contributor understand the system 3 months from now? Is there transient task detail that should be removed?
- Pass/fail on doc quality; iterate if needed

---

## Phase 5: E2E Testing & Completion

#### Task 8.5: E2E Test Repository Setup (from Phase 4, pre-requisite for T-7)
*(See above in Phase 4)*

#### Task 10: E2E Integration Test
- **Change:** Using the test repo from T-8.5, manually trigger both workflow_dispatch and repository_dispatch with realistic crash payloads. Verify PR creation, content, and diff scoping.
- **Files:** (test repo artifacts; no changes to primary repo)
- **Tier:** cheap
- **Done when:**
  - Workflow_dispatch trigger with sample crash fields succeeds; PR is created and merged to test branch
  - PR title contains crash signature; body contains full stack trace, app version, and agent summary
  - PR diff is scoped to files implicated by stack trace (no unrelated changes)
  - Repository_dispatch trigger with client_payload succeeds; produces a separate PR (not the same PR as workflow_dispatch)
  - Both workflows run without timeout or authentication errors
  - Agent output is captured and included in PR body
  - Log-scan step passed (no secrets leaked in logs)
- **Blockers:** 
  - Test repo (T-8.5) must be set up first
  - Test app must have a reproducible crash signature

#### VERIFY: E2E & Completion
- Run both workflows on test repo
- Confirm: PR creation, content correctness, diff scoping, no secret leakage
- Report: both workflows successful, PRs created, final status

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Claude Code CLI hangs in non-interactive mode on GitHub Actions | HIGH | Validate in Task 1 with smoke test on ubuntu-latest runner. If hangs, escalate — may require different agent (aider, codex) or API-based approach instead of CLI. |
| Stack trace file scanning misses implicated .java files or finds false positives | MEDIUM | Implement defensive: if no files found, fail loudly with instructions. Test with real crash payloads (Crashlytics format) in Task 2. |
| PR body contains secrets or sensitive data from agent output | HIGH | Security audit in Task 7: review agent output for credentials, redact if found. Test with sample payloads that include env vars or keys in stack trace. |
| GitHub permissions too broad (e.g., write to code, delete branches) | MEDIUM | Limit to `contents: write, pull-requests: write` in workflows. Audit action.yml in Task 3. |
| Future agent contributors misunderstand the install.sh / run.sh interface | LOW | Document in README (Task 6) and docs/adding-agents.md (Task 9). Provide aider/codex/gemini scaffolds with comments in scripts. |

## Notes
- Each task results in a git commit
- Verify checkpoints after Phase 1, 2, 3, 4 — stop and report before proceeding
- Base branch: main
- All code pushed before reviewer dispatch
