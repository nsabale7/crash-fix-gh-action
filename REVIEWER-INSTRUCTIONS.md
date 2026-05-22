# Code Review — Crash Auto-Fix GitHub Action v1.0

## Your Role
You are the **reviewer** (🟩 gh-rev) for PR #1. Your job is to validate the implementation against the plan, verify all tests pass, and provide feedback before merge.

## Review Checklist

### 1. Code Structure & Artifacts
- [ ] `action.yml` — Composite action with 9 steps, proper error handling (set -e, || exit 1)
- [ ] `.github/workflows/ci.yml` — CI pipeline with linting, testing, secret masking
- [ ] `.github/workflows/crash-auto-fix-manual.yml` — workflow_dispatch trigger (12 inputs)
- [ ] `.github/workflows/crash-auto-fix-dispatch.yml` — repository_dispatch trigger (9 inputs)
- [ ] Agent scaffolding: `action/agents/{claude,aider,codex,gemini}/install.sh|run.sh` (8 scripts total)
- [ ] `action/build-prompt.sh` — Prompt building logic with proper variable handling
- [ ] `action/pr-body-template.md` — PR body template with placeholders

### 2. Documentation
- [ ] `README.md` (658+ lines) — User guide with examples, troubleshooting, FAQ
- [ ] `SECURITY.md` (839+ lines) — Security audit, no issues found
- [ ] `ARCHITECTURE.md` (411+ lines) — System design and components
- [ ] `DECISIONS.md` (447+ lines) — 16 design decisions with rationale
- [ ] `ROADMAP.md` (403+ lines) — v1-v3 vision
- [ ] `E2E-TESTING.md`, `INTEGRATION.md` — E2E guides
- [ ] `E2E-TEST-REPORT.md`, `E2E-VALIDATION-CHECKLIST.md` — Test results

### 3. Test Suites
Run each test script and confirm PASS status:

```bash
# From repo root
bash test/test-input-handling.sh      # 6/6 tests ✓
bash test/test-task3-workflow.sh      # 9/9 tests ✓
bash test/test-integration-workflows.sh   # 25/25 tests ✓
bash test/test-agents.sh              # 27/27 tests ✓
```

All tests must pass with 0 failures.

### 4. Security Validation
- [ ] No hardcoded secrets in any scripts
- [ ] All API keys read from environment variables (AGENT_API_KEY, ANTHROPIC_API_KEY, etc.)
- [ ] Secret masking in CI (::add-mask::)
- [ ] Log scan for secret patterns (sk-ant-, sk-, ghp_, etc.) with exit 1 on leak
- [ ] Minimal GitHub Actions permissions (contents:write, pull-requests:write)
- [ ] Input sanitization (branch names, crash IDs properly slugified)

### 5. Agent Implementation
Each agent (claude, aider, codex, gemini) should have:
- [ ] `install.sh` with retry logic (max 3 attempts, exponential backoff)
- [ ] `run.sh` with:
  - Default file paths: `/tmp/crash-fix-prompt.txt`, `/tmp/crash-fix-output.txt`
  - Error handling for missing prompt file
  - Error handling for missing AGENT_API_KEY
  - Proper error exit codes (exit 1 on failure)
  - API key mapping (OPENAI_API_KEY, GEMINI_API_KEY, ANTHROPIC_API_KEY)

### 6. CI Status
- [ ] PR #1 CI checks: All PASS ✅
  - Lint and test workflow passing
  - No actionlint violations
  - All test suites passing
  - Log scan clean (no secrets detected)
  - Secret masking active

### 7. Commits & History
- [ ] 18+ commits on sprint/crash-fix-action-v1
- [ ] Commits reference task IDs (task/1, task/2, etc.)
- [ ] No commits to main branch
- [ ] progress.json updated with all 17 tasks

## Issues to Flag

🔴 **BLOCKER** — Must be fixed before merge:
- Any test failure
- Any security issue (hardcoded secrets, credential leakage)
- Missing deliverables from the plan
- CI checks failing

🟡 **MINOR** — Nice to have, but not blocking:
- Documentation typos
- Non-functional code comments
- Small refactoring opportunities

## Final Sign-Off

Once you've completed the review:

1. Create `REVIEW.md` with your findings:
   ```
   # Code Review — PR #1

   **Reviewer:** gh-rev
   **Date:** [date]
   **Status:** ✅ APPROVED / ⚠️ CHANGES REQUESTED

   ## Findings
   - [issue 1]
   - [issue 2]

   ## Test Results
   [Output from test suites]

   ## Sign-Off
   All deliverables verified. Ready for merge.
   ```

2. Commit and push to sprint/crash-fix-action-v1
3. Report findings to PM

---

**Key Success Criteria:**
- ✅ All tests passing
- ✅ No security issues
- ✅ All deliverables in place
- ✅ Documentation complete and comprehensive
- ✅ CI checks green

Good luck! 🚀
