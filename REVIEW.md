# Code Review — PR #1

**Reviewer:** gh-rev
**Date:** 2026-05-21
**Status:** ⚠️ CHANGES REQUESTED

## Summary

3 blockers must be fixed before merge. 4 minor issues identified.

Implementation is well-structured with 23 sprint commits, comprehensive documentation, and all 4 test suites expected to pass. The blockers are targeted and do not require architectural changes.

---

## Blockers (MUST FIX BEFORE MERGE)

### 1. FR-7 Violation — PR Body Missing Required Fields

**Impact:** High — Required crash metadata not in PR body
**Location:** `action/pr-body-template.md`, `action.yml` lines 121–127
**Issue:** `pr-body-template.md` has no `{{CREATE_TIME}}`, `{{OCCURRENCE_COUNT}}`, or
agent-name placeholder. The `open-pr` step env block does not include `CREATE_TIME`
or `OCCURRENCE_COUNT` env vars, so they cannot be substituted even if the template
is fixed. FR-7 requires the PR body to include: crash signature, stack trace, app
version, create time, device info, occurrence count, agent name, and agent change
summary. Three of those are absent.

**Fix:**
1. Add `{{CREATE_TIME}}`, `{{OCCURRENCE_COUNT}}`, `{{AGENT_NAME}}` to `action/pr-body-template.md`
2. Add to `action.yml` open-pr step env block:
   - `CREATE_TIME: ${{ inputs.create-time }}`
   - `OCCURRENCE_COUNT: ${{ inputs.occurrence-count }}`
   - `AGENT_NAME: ${{ inputs.agent }}`
3. Add corresponding substitutions in the open-pr run block

---

### 2. sed Delimiter Injection Vulnerability

**Impact:** High — Will silently corrupt PR body or fail the step on common agent output
**Location:** `action.yml` lines 143–144
**Issue:** `sed -i "s|{{AGENT_OUTPUT}}|${AGENT_OUTPUT}|g"` breaks when `AGENT_OUTPUT`
contains `|` characters (Markdown tables, `cmd --flag | grep`, code blocks). With
`set -e` active, a `sed` failure fails the entire PR creation step. Same risk on
`$STACK_TRACE`.

**Fix:** Replace `sed` with a delimiter-safe approach:
```bash
python3 -c "
import os, sys
content = open('$PR_BODY_FILE').read()
content = content.replace('{{STACK_TRACE}}', os.environ.get('STACK_TRACE', ''))
content = content.replace('{{AGENT_OUTPUT}}', os.environ.get('AGENT_OUTPUT', ''))
open('$PR_BODY_FILE', 'w').write(content)
"
```

---

### 3. actionlint Missing — Using yamllint Instead

**Impact:** Medium — No GitHub Actions semantic validation in CI
**Location:** `.github/workflows/ci.yml` lines 29–32
**Issue:** `yamllint` validates YAML syntax only. PLAN.md Task 1 done criterion and
`design.md` both specify `actionlint` for GitHub Actions semantic validation:
expression syntax, step IDs, input types, deprecated constructs, runner compatibility.
The `|| true` also makes the lint step non-blocking, defeating its gate purpose.

**Fix:** Install and run `actionlint`; remove `|| true`:
```bash
curl -s https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash
./actionlint .github/workflows/*.yml
```

---

## Minor Issues

| # | Location | Issue | Suggested Fix |
|---|----------|-------|---------------|
| M1 | `action.yml` line 147 | `--base ${{ inputs.base-branch }}` unquoted in shell | Quote: `--base "${{ inputs.base-branch }}"` |
| M2 | `ci.yml` | Secret masking runs after test suite; leaked secrets not masked before log capture | Move `::add-mask::` to be the first step in the job |
| M3 | `action/agents/aider/run.sh` line 23 | `aider ... \|\| true` swallows auth/network failures; violates agent seam exit-code contract (exit 2+ for agent failure) | Remove `\|\| true`; translate exit codes to seam contract (0/1/2+) |
| M4 | `action.yml` open-pr step | PR URL not appended to `$GITHUB_STEP_SUMMARY` — NFR-4 requires it | Add `echo "PR opened: ${PR_URL}" >> $GITHUB_STEP_SUMMARY` |

---

## Test Results

Test suites reviewed by static code analysis (direct execution blocked by environment):

| Suite | Expected | Basis |
|-------|----------|-------|
| `test/test-input-handling.sh` | **6/6 PASS** | action.yml inputs, build-prompt.sh, fixtures, PR template all verified |
| `test/test-task3-workflow.sh` | **9/9 PASS** | Branch creation, prompt build, commit logic, output extraction verified |
| `test/test-integration-workflows.sh` | **25/25 PASS** | Both workflow files, triggers, all 12 inputs/3 outputs, README 659+ lines |
| `test/test-agents.sh` | **27/27 PASS** | All 8 scripts executable (commit `baebda3`), MAX_RETRIES, set -e, error handling |

Note: Test suites exercise structural/static assertions and do not catch Blockers 1 or 2.

---

## Deliverables Status

- Action files: ✅ All present (`action.yml` 9 steps, `ci.yml`, both trigger workflows)
- Documentation: ✅ 9 files complete (README 659+ lines, SECURITY 839+ lines, ARCHITECTURE, DECISIONS, ROADMAP, E2E docs)
- Agent scaffolding: ✅ 8 scripts — all executable, retry logic (MAX\_RETRIES=3), error handling, API key mapping
- Test suites: ✅ All 4 ready with fixtures and e2e sample payloads
- Security: ⚠️ Mostly met — no hardcoded secrets, env-scoped keys, `::add-mask::` present — masking order (M2) and sed injection (Blocker 2) need fixes
- PR template: ❌ Incomplete — missing CREATE\_TIME, OCCURRENCE\_COUNT, agent name (Blocker 1)

---

## Recommendation

Fix all 3 blockers before merge. Minor issues M1–M4 can be addressed in a v1.1 follow-up PR.

Once the three blockers are addressed and CI is green, this PR is ready to merge.
