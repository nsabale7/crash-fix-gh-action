# Design Decisions — Crash Auto-Fix GitHub Action

This document captures the key architectural and implementation decisions made during v1 development, with rationale for each. These decisions form the foundation for future enhancements and agent contributions.

## Foundational Decisions

### D1: Composite Action (Shell Scripts) vs. JavaScript Action

**Decision:** Implement as a composite action with shell scripts.

**Context:**
- Action needs to install diverse agent CLIs (npm for Claude, pip for Aider/Codex/Gemini, etc.)
- Runners vary in OS and tooling (Linux, macOS, Windows with WSL)
- Team prioritizes agent extensibility and simplicity over rich JavaScript ecosystem

**Alternatives Considered:**
1. **JavaScript Action** — bundle Node.js app that spawns agent processes
   - Pros: Rich npm ecosystem, easier debugging, natural for JS tools
   - Cons: Node required on all runners, bundling complexity, harder to support non-JS agents
2. **Docker Action** — containerized shell environment
   - Pros: Predictable environment, no runner setup needed
   - Cons: Slow cold start, no support on Windows runners, licensing/registry dependencies

**Decision Rationale:**
- Shell scripts directly invoke external CLIs without intermediary runtime
- `ubuntu-latest` and other GitHub-hosted runners include bash, git, npm, and pip out-of-box
- Composite action semantics map directly to GitHub Actions UI and CI/CD pipelines
- Future agent contributors can add install.sh and run.sh without learning JavaScript

**Implications:**
- ✓ Portable across Linux, macOS, Windows (WSL) runners
- ✓ No build/bundle step; source code is executable
- ✗ Shell script debugging harder than JavaScript
- ✗ Error handling must be explicit (set -e, || exit 1)

---

### D2: Agent Install in Workflow Step vs. Pre-Built Runner Image

**Decision:** Install agent CLI dynamically in the workflow step.

**Context:**
- Action will support multiple agents (Claude, Aider, Codex, Gemini) in different versions
- Pre-building a custom runner image would require maintaining matrix of OS × agent combinations
- GitHub-hosted runners are already optimized for common build tools (Node, Python, etc.)

**Alternatives Considered:**
1. **Pre-built custom runner image** — Docker image with all agents pre-installed
   - Pros: Faster workflow, no installation latency
   - Cons: Maintenance burden, version conflicts, incompatible with GitHub-hosted runners
2. **Assumption: Agent pre-installed on runner** — require users to customize runners
   - Pros: Simplest for us
   - Cons: Shifts maintenance to users, breaks portability

**Decision Rationale:**
- Installing Claude (npm), Aider (pip), etc. is fast on modern runners (typically < 30s)
- `ubuntu-latest` ships Node 20+ and Python 3.x; installations use system package managers
- Reproduces user environment exactly (e.g., "npm install always works the way users run it locally")
- Enables future improvements (e.g., multi-agent matrix runs) without runner rebuild

**Implications:**
- ✓ No runner setup burden on users
- ✓ Each run gets fresh agent version (automatic updates)
- ✗ 15-30s installation latency per run (acceptable for crash-fix use case)
- ✗ Installation failures become workflow failures (mitigated by retry logic in install.sh)

---

### D3: Non-TTY CLI Execution (--print flag + file I/O)

**Decision:** Agents run non-interactively via `--print` flag and file redirection, not MCP loop.

**Context:**
- GitHub Actions runners don't allocate a TTY (tty: false)
- Claude Code CLI supports --print flag for non-interactive invocation
- MCP loop is stateful and designed for interactive use; GitHub Actions are ephemeral

**Alternatives Considered:**
1. **MCP loop (interactive)** — spawn `claude` and interact via stdio
   - Pros: Full interactive experience, supports tool use, multi-turn conversation
   - Cons: Hangs without TTY, complex state management in ephemeral runner, token burn
2. **API-based invocation** — call Anthropic API directly (no CLI)
   - Pros: Deterministic, no TTY dependency
   - Cons: Requires SDK integration, more code, less portable across agents

**Decision Rationale:**
- Non-TTY constraint is fundamental to GitHub Actions; we must adapt
- `--print` flag documented in Claude Code CLI; uses single-turn invocation
- File-based I/O is standard Unix idiom; works with all CLI tools
- Avoids state persistence issues in ephemeral runner (no leftover MCP processes)
- Single-turn invocation per run is appropriate for crash context (bounded problem)

**Implications:**
- ✓ Works reliably on GitHub-hosted runners without timeout/hang issues
- ✓ No MCP server lifecycle management needed
- ✓ Simple to test: `echo prompt | claude --print > output`
- ✗ No interactive debugging; agent doesn't ask clarifying questions
- ✗ No multi-turn conversation (mitigated by comprehensive prompts)

---

### D4: PR-Based Workflow (Never Auto-Merge)

**Decision:** Always open a PR; never auto-merge to main.

**Context:**
- Automated fixes are generated by AI; fallibility is inherent
- Consumer repos may have branch protection, CI requirements, code review policies
- Audit trail (PR discussion, CI results, merge timestamp) is valuable for crash forensics

**Alternatives Considered:**
1. **Direct commit to main** — push fix directly if agent is confident
   - Pros: Faster deployment
   - Cons: Bypasses CI, no human review, risky for production
2. **Auto-merge if CI passes** — open PR, merge if tests pass
   - Pros: Faster pipeline for confident fixes
   - Cons: Still bypasses code review, doesn't handle flaky tests, may violate repo policies

**Decision Rationale:**
- Even high-confidence AI fixes need human eyes before production deployment
- PR review is standard industry practice for all code changes
- CI failures on PR (lint, tests) signal potential issues with the fix
- PR body includes agent reasoning, allowing humans to validate the approach
- Merge commits link crash payload to code history

**Implications:**
- ✓ All fixes go through standard code review and CI
- ✓ Audit trail: PR discussion, CI results, blame history
- ✓ Respects target repo's merge policies and branch protection
- ✗ Slower time-to-fix (requires manual review)
- ✗ PRs may be merged carelessly without review (user responsibility)

---

### D5: Pluggable Agent Seam (install.sh + run.sh Convention)

**Decision:** Each agent gets two scripts (install.sh, run.sh) in its own folder; action.yml is agent-agnostic.

**Context:**
- v1 ships Claude wired; Aider/Codex/Gemini scaffolded for future
- Different agents have different installation methods (npm, pip, etc.)
- Goal: Future contributors should add agents without modifying action.yml or workflows

**Alternatives Considered:**
1. **Hardcoded agent logic in action.yml** — if-else per agent in steps
   - Pros: Explicit, easy to understand
   - Cons: action.yml grows, agents are tightly coupled, harder to add new agents
2. **Runtime lookup in single script** — action/run-agent.sh with switch statement
   - Pros: Centralized agent logic
   - Cons: Single point of failure, harder to unit test, still couples agents to main repo
3. **External agent registry** — reference agents from external repositories
   - Pros: Decoupled, agents evolve independently
   - Cons: Network dependency, version resolution complexity, trusted source problem

**Decision Rationale:**
- Two-script interface (install.sh, run.sh) is simple and Unix-like
- File system discovery (`action/agents/<name>/`) is more flexible than registry
- Minimal interface allows agents to be simple, self-contained, and testable
- Scaffolded stubs in v1 (exit with "not yet implemented") allow future PRs to add implementations without refactoring core
- Each agent's scripts can be customized (different retry logic, different prompt post-processing, etc.) without affecting others

**Implications:**
- ✓ New agents added via simple PR: create folder, drop two scripts
- ✓ Each agent can be tested independently
- ✓ No coupling between agents; one broken agent doesn't break others
- ✓ Flexible: agents can override behavior (e.g., Aider-specific prompt format)
- ✗ More files than monolithic approach (8 scripts for 4 agents)
- ✗ Requires documentation of the interface (covered in README and ARCHITECTURE.md)

---

### D6: File-Based I/O (/tmp/) vs. Environment Variables

**Decision:** Prompt and agent output passed via /tmp/ files, not environment variables.

**Context:**
- Crash stack traces can be large (100s of lines); code snippets add more bulk
- Environment variable size limits vary by shell (typically 1-2MB ceiling, often lower in GitHub Actions)
- Agent CLIs expect stdin/files, not environment-injected prompts

**Alternatives Considered:**
1. **Environment variables** — export PROMPT and OUTPUT_FILE vars
   - Pros: No file system I/O, simpler cleanup
   - Cons: Size limits, shell escaping complexity, less natural for CLI tools
2. **Stdin/stdout piping** — pipe prompt directly to agent, capture output
   - Pros: Natural for Unix CLI tools
   - Cons: Requires capturing return code separately, harder to debug (can't inspect /tmp/ files)

**Decision Rationale:**
- Stack traces are frequently > 1KB; adding code snippets can exceed env var limits
- File I/O is more readable: `claude < /tmp/crash-fix-prompt.txt > /tmp/agent-output.txt`
- /tmp/ files can be inspected by CI steps for debugging (e.g., "print agent output on failure")
- Works across all runners (Linux, macOS, Windows WSL)
- GitHub Actions can upload /tmp/ artifacts for post-mortem analysis

**Implications:**
- ✓ No size limits for prompt/output
- ✓ Readable file I/O semantics
- ✓ Debuggable: files persist on runner (can inspect in post-run steps)
- ✓ Works with any CLI tool
- ✗ Small latency for file I/O (negligible)
- ✗ Requires cleanup of /tmp/ files (or rely on runner ephemeral cleanup)

---

### D7: Non-Interactive Execution (--dangerously-skip-permissions flag)

**Decision:** Use `--dangerously-skip-permissions` flag when invoking Claude CLI.

**Context:**
- GitHub Actions runner context lacks MCP permissions framework
- Claude Code CLI defaults to interactive permission prompts
- We've pre-vetted the crash context (signature, stack trace are crash metadata; not arbitrary code)

**Alternatives Considered:**
1. **Interactive permissions** — let CLI prompt during workflow
   - Pros: Stricter security, user controls tool access
   - Cons: Hangs in non-TTY environment, unacceptable in automated workflows
2. **Pre-configured permissions** — write .claude/settings.json with allowlist
   - Pros: Explicit permissions in code
   - Cons: Complex setup, tight coupling to Claude CLI version/schema

**Decision Rationale:**
- GitHub Actions runners are untrusted by default; no interactive approval is possible
- Crash payloads are curated by upstream systems (Crashlytics, Sentry, etc.); not arbitrary user input
- --dangerously-skip-permissions is documented in Claude Code CLI; explicitly designed for CI use
- Prompt builder (action/build-prompt.sh) enforces scope: "limit edits to crash-related files only"
- Security audit (SECURITY.md) reviews agent output for injection/exfil risks

**Implications:**
- ✓ Workflow completes without hanging
- ✓ No user interaction required
- ✗ Agents have broad tool access (mitigated by prompt scoping)
- ✗ Name is scary (dangerously-skip-permissions); users must understand the trade-off

---

### D8: Branch Naming Convention: crash-fix/<signature-slug>-<run-id>

**Decision:** Branch names are `crash-fix/<signature-slug>-<run-id>`, where signature-slug is lowercased, special chars → `-`, run-id = github.run_id.

**Context:**
- Multiple crash fixes may be in flight for different crashes (and same crash multiple times)
- Branch names should be human-readable (crash signature) and globally unique (run-id)
- GitHub branch naming restrictions: no .., @{, space, ~, ^, :, ?, *, [, \

**Alternatives Considered:**
1. **Just run-id** — `crash-fix/12345`
   - Pros: Simple, guaranteed unique
   - Cons: No hint what the branch is for; engineers must check PR to understand
2. **Just signature** — `crash-fix/NullPointerException`
   - Pros: Very readable
   - Cons: Collides if same crash triggers twice; can't push second PR
3. **UUID** — `crash-fix/<uuid>`
   - Pros: Unique, short
   - Cons: No semantic meaning

**Decision Rationale:**
- Signature slug (humanized) + run-id (unique) balances readability and uniqueness
- `git log` shows branch names; engineers should understand them at a glance
- `github.run_id` is deterministic, per-workflow-run unique, and not guessable
- Slug sanitization (lowercase, special chars → `-`) ensures GitHub compatibility
- If branch already exists (duplicate crash), step fails with clear error (no orphaned branches)

**Implications:**
- ✓ Branch names are self-documenting
- ✓ No collision issues; each run gets unique branch
- ✓ Git history is readable
- ✗ Branch names can be long (signature + 10-digit run-id)
- ✗ Slug sanitization may lose details (e.g., "NullPointerException::getMessage()" → "nullpointerexception-getmessage")

---

### D9: Separate Prompt Builder Script (action/build-prompt.sh)

**Decision:** Prompt building logic lives in a separate, reusable script, not inlined in action.yml.

**Context:**
- Prompt construction is complex: stack trace parsing, file discovery, format assembly
- Prompt format will likely evolve; centralizing makes updates easier
- Prompt logic should be testable independently

**Alternatives Considered:**
1. **Inlined in action.yml** — embed shell logic in Step 4
   - Pros: Single file to maintain
   - Cons: action.yml becomes large, harder to test, harder to reuse
2. **Python script** — action/build-prompt.py
   - Pros: Easier to write complex parsing logic
   - Cons: Requires Python on runner (not as reliable as shell), less portable

**Decision Rationale:**
- Bash is available on all GitHub-hosted runners; no extra dependency
- Separate script enables unit testing (test/test-input-handling.sh validates prompt output)
- Prompt builder can be used standalone (e.g., batch processing, debugging)
- Changes to prompt format don't require editing action.yml

**Implications:**
- ✓ Testable: script can be invoked with sample inputs, output validated
- ✓ Reusable: other workflows can use action/build-prompt.sh without full Action
- ✓ Maintainable: prompt changes isolated to one file
- ✗ One more file to track (but worth the trade-off)

---

## Phase-Specific Decisions

### Phase 1: Foundation

**D10: Include Smoke Test in Task 1 (Riskiest Assumption)**

**Decision:** Validate Claude Code CLI's non-interactive behavior early (Task 1) via smoke test on ubuntu-latest runner.

**Rationale:**
- If Claude CLI hangs without TTY, entire approach fails; detect early
- Smoke test: invoke `claude --print < prompt.txt > output.txt` on GitHub-hosted runner
- Success criteria: completes in < 5 min, output is non-empty, exit code 0

**Implications:**
- ✓ Early validation prevents wasted effort
- ✗ Requires running actions in CI (cost, time)

---

**D11: Scaffolded Agents with "Not Yet Implemented" Exit**

**Decision:** Aider, Codex, Gemini folders ship with install.sh and run.sh that exit 1 with clear message.

**Rationale:**
- Signals to future contributors that the hooks exist, just not wired
- Prevents confusing "folder not found" error if user selects unimplemented agent
- Future PRs can add implementations without restructuring

**Implications:**
- ✓ Clear signal to future contributors (seam exists, just empty)
- ✓ Self-contained PRs: add agent = drop scripts, no refactoring
- ✗ Scaffolded scripts need documenting (README section "Adding a new agent")

---

### Phase 2: Integration

**D12: Two Trigger Templates (workflow_dispatch + repository_dispatch)**

**Decision:** .github/workflows/ includes both crash-fix-manual.yml and crash-fix-webhook.yml as templates.

**Rationale:**
- workflow_dispatch: for manual testing and ad-hoc fixes (engineers trigger manually)
- repository_dispatch: for external dispatchers (Crashlytics, Sentry, Cloud Functions)
- Both are in this repo as templates; users copy into their own repos

**Implications:**
- ✓ Covers both main use cases
- ✓ Documented examples in README
- ✗ Users must copy workflows to their repos (not automatic)

---

**D13: Single AGENT_API_KEY Input (Polymorphic, Not Polymorphic)**

**Decision:** Single `api-key` input for all agents; agent's run.sh maps to provider-specific env var.

**Rationale:**
- One API key per workflow run (most common case)
- Agent script handles mapping: `ANTHROPIC_API_KEY="$AGENT_API_KEY"` for Claude, etc.
- If future agent needs *two* keys (e.g., embedding + generation), can extend input shape then

**Implications:**
- ✓ Simpler input contract
- ✓ Agent script encapsulates provider details
- ✗ Unclear which key is needed until you read the agent script (mitigated by README docs)

---

### Phase 3: Security

**D14: Secret Masking + Log Scanning in CI**

**Decision:** CI workflow (.github/workflows/ci.yml) includes both ::add-mask:: step and post-run log-scan step.

**Rationale:**
- GitHub Actions ::add-mask:: redacts known secret patterns (ANTHROPIC_API_KEY, AGENT_API_KEY, etc.)
- Post-run log-scan step greps for patterns (sk-ant-, sk-, ghp_) and fails job if found (defense-in-depth)
- Catches cases where agent output or error messages leak credentials

**Implications:**
- ✓ Defense-in-depth: two layers of secret protection
- ✓ Log-scan test case intentionally leaks a secret to verify detection works
- ✗ Regex patterns may have false positives/negatives (mitigated by test cases)

---

**D15: Minimal GitHub Permissions (contents:write, pull-requests:write)**

**Decision:** Workflows request only `contents:write` (for git push) and `pull-requests:write` (for PR creation).

**Rationale:**
- No delete-branch, no workflows:write, no admin
- Principle of least privilege: grant only what's needed
- Reduces blast radius if GITHUB_TOKEN is compromised

**Implications:**
- ✓ Secure by default
- ✗ More granular than typical "write-all" workflows (user must remember to set permissions)

---

### Phase 4: Documentation

**D16: Architecture/Design Docs (ARCHITECTURE.md, DESIGN.md, DECISIONS.md, ROADMAP.md)**

**Decision:** Four separate documents for different audiences and purposes.

**Rationale:**
- **ARCHITECTURE.md:** For systems architects and new contributors; covers components, data flow, design decisions
- **DESIGN.md:** For product managers and stakeholders; covers problem, solution, requirements, constraints
- **DECISIONS.md:** For developers; explains the "why" behind each choice
- **ROADMAP.md:** For future planners; lists enhancements, phases, research ideas

**Implications:**
- ✓ Audience-appropriate documentation
- ✓ Durable knowledge captured (not task-level notes)
- ✗ Risk of duplication between docs (mitigated by clear scoping)

---

## Future Decisions (Deferred to Roadmap)

These decisions are intentionally deferred to v2+ to keep v1 focused:

- **D-Future-1:** Multi-language prompt support — Detect language (Java, Python, JavaScript, etc.) and use language-specific prompt
- **D-Future-2:** Crash deduplication — Detect if same crash_id has PR already; update existing PR instead of creating new one
- **D-Future-3:** Advanced error handling — Retry logic with exponential backoff if agent times out or API errors
- **D-Future-4:** Feedback collection — Add PR comment template for engineers to indicate fix quality (1-5 stars); aggregate metrics
- **D-Future-5:** Agent selection heuristics — Automatically pick best agent based on crash type, language, API cost
- **D-Future-6:** Integration with crash analytics platforms — Pre-built integrations for Crashlytics, Sentry, Firebase

---

## Summary

The Crash Auto-Fix Action's design prioritizes **simplicity, extensibility, and safety** over feature richness:

1. **Simplicity:** Shell scripts, two-step agent interface, file-based I/O keep implementation lightweight
2. **Extensibility:** Pluggable agent seam allows future contributors to add agents without modifying core
3. **Safety:** PR-based workflow, secret masking, input sanitization, minimal permissions ensure security

Each decision is a trade-off; the document above explains the alternatives and rationale for each choice.
