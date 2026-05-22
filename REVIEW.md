# Code Review — PR #1 (Follow-Up 2)

**Reviewer:** gh-rev
**Date:** 2026-05-22
**Status:** ⚠️ CHANGES REQUESTED — actionlint install method still broken

## Summary

2 of 3 blockers fully resolved. Blocker 3 (actionlint) remains broken: the installation
method changed from yamllint to actionlint, but `sudo apt-get install -y actionlint`
fails on Ubuntu because actionlint is not in the standard apt repository.
CI run 26274130951 confirms: `E: Unable to locate package actionlint`.

---

## Blocker Verification

### Blocker 1 — PR Body Missing Fields ✅ RESOLVED

`action/pr-body-template.md` now includes `{{OCCURRENCE_COUNT}}` and `{{CREATE_TIME}}`:
```
- **Occurrences:** {{OCCURRENCE_COUNT}}
- **Detected:** {{CREATE_TIME}}
```
`action.yml` Open PR step env block now includes both fields with correct envsubst.

### Blocker 2 — sed Delimiter Injection ✅ RESOLVED

The Open PR step now uses `envsubst` for all placeholder substitution, eliminating
the pipe/bracket injection risk. The comment confirms the intent:
```bash
# Use envsubst for safe placeholder substitution (avoids sed delimiter injection)
```

### Blocker 3 — actionlint CI Install ❌ NOT FIXED (CI STILL FAILING)

`yamllint` was replaced with `actionlint` in ci.yml, but the install command is wrong:
```bash
# FAILS — actionlint is not in Ubuntu's apt repository
sudo apt-get update && sudo apt-get install -y actionlint
# E: Unable to locate package actionlint
```

CI run 26274130951 confirms: `E: Unable to locate package actionlint`.
actionlint is a standalone Go binary — it must be downloaded from GitHub releases.

**Required fix** for `.github/workflows/ci.yml`:
```yaml
- name: Lint workflows (actionlint)
  run: |
    curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash
    ./actionlint .github/workflows/ || exit 1
    echo "Workflow linting passed"
```

---

## Test Results (Local)

3 of 4 test suites pass locally:

| Suite | Result |
|-------|--------|
| `test/test-input-handling.sh` | ✅ 6/6 PASS |
| `test/test-task3-workflow.sh` | ✅ 9/9 PASS |
| `test/test-agents.sh` | ✅ 39/39 PASS |
| `test/test-integration-workflows.sh` | ❌ FAIL (Windows env: `python3` alias lacks yaml module) |

Note: test-integration-workflows.sh failure is a local Windows environment issue only —
`python3` on this machine maps to the Windows Store alias. On Ubuntu (CI), `python3 -c "import yaml"` works correctly. Not a code defect.

## CI Status

❌ CI failing — run 26274130951

- Step: "Lint workflows (actionlint)"
- Error: `E: Unable to locate package actionlint`
- Root cause: actionlint distributed as standalone binary, not via apt

---

## Required Fix

One change needed in `.github/workflows/ci.yml` lines 33–37:

**Before:**
```yaml
- name: Lint workflows (actionlint)
  run: |
    sudo apt-get update && sudo apt-get install -y actionlint
    actionlint .github/workflows/ || exit 1
    echo "Workflow linting passed"
```

**After:**
```yaml
- name: Lint workflows (actionlint)
  run: |
    curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash
    ./actionlint .github/workflows/ || exit 1
    echo "Workflow linting passed"
```

Once this fix is pushed and CI turns green, this PR is ready to merge.
All code-level logic is correct. Blockers 1 and 2 are fully resolved.

---

## Findings Status

| # | Issue | Status |
|---|-------|--------|
| B1 | PR body missing CREATE_TIME, OCCURRENCE_COUNT | ✅ Fixed (commit d76e137) |
| B2 | sed delimiter injection | ✅ Fixed (commit d76e137) |
| B3 | actionlint not in CI | ❌ Wrong install method — CI still failing |
| M1 | base-branch unquoted in gh pr create | ✅ Fixed (commit d76e137) |
| M2 | Secret masking after tests | ✅ Fixed (commit d76e137) |
| M3 | aider run.sh swallows failures | Not addressed (non-blocking) |
| M4 | PR URL not in GITHUB_STEP_SUMMARY | Not addressed (non-blocking) |
