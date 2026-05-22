# E2E Test Suite for crash-fix-gh-action

This directory contains the end-to-end test framework for validating the crash-fix-gh-action in realistic GitHub Actions environments.

---

## Overview

The E2E test suite validates:
- **Workflow triggers**: Both `workflow_dispatch` (manual) and `repository_dispatch` (webhook) function correctly
- **Agent integration**: Claude CLI (and other agents) are invoked correctly and produce output
- **PR creation**: Pull requests are created with correct titles, bodies, and diffs
- **Crash payload handling**: Various crash formats (Android, iOS, Web) are parsed and processed correctly
- **Security**: No secrets are leaked in logs or PR bodies
- **Error handling**: Failures are handled gracefully with informative messages

---

## Test Strategy

### Phases

1. **Unit Testing** (Local): Validate components in isolation
   - Parse crash payloads (test/fixtures/)
   - Build prompts (action/build-prompt.sh)
   - Extract file paths from stack traces

2. **Integration Testing** (Local): Validate workflows in a simulated GitHub environment
   - Simulate workflow triggers (workflow_dispatch, repository_dispatch)
   - Mock GitHub API responses
   - Verify action.yml composition

3. **E2E Testing** (Real GitHub): Validate in production GitHub Actions environment
   - Create real PRs in test repository
   - Validate workflow execution end-to-end
   - Inspect PR bodies and diffs
   - Verify secret masking and log scanning

---

## Test Scenarios

### Scenario 1: workflow_dispatch with Android NPE
**Objective**: Validate manual trigger with Android crash payload

**Steps**:
1. Trigger workflow_dispatch with `sample-payload-android-npe.json`
2. Monitor workflow execution in GitHub Actions
3. Verify PR is created with:
   - Title includes "NullPointerException in MainActivity"
   - Body contains crash ID, app version, stack trace
   - Diff shows null checks added
4. Verify branch naming: `crash-fix/nullpointerexception-in-mainactivity-<run-id>`

**Expected Result**: PR created successfully, fix proposed by Claude

---

### Scenario 2: repository_dispatch with iOS Crash
**Objective**: Validate webhook trigger with iOS crash payload

**Steps**:
1. Prepare repository_dispatch event with `sample-payload-ios-crash.json` wrapped in `client_payload`
2. Trigger via GitHub API: `POST /repos/{owner}/{repo}/dispatches`
3. Monitor workflow execution
4. Verify PR is created with:
   - Title includes "EXC_BAD_ACCESS in UIViewController"
   - Crash details from iOS stack trace
5. Verify error handling for iOS-specific issues (memory corruption, etc.)

**Expected Result**: PR created with iOS-specific fix proposal

---

### Scenario 3: Web JavaScript Error
**Objective**: Validate handling of web/JavaScript crashes

**Steps**:
1. Trigger workflow_dispatch with `sample-payload-web-error.json`
2. Verify Claude understands browser-specific context
3. Check PR diff for JavaScript error handling (try/catch, type checks, etc.)

**Expected Result**: PR with JavaScript-specific fix patterns

---

### Scenario 4: Large Stack Trace
**Objective**: Validate handling of large/complex crash payloads

**Steps**:
1. Trigger with a stack trace > 10KB
2. Verify Claude processes the full trace (not truncated)
3. Verify workflow doesn't timeout

**Expected Result**: Full stack trace processed, PR created

---

### Scenario 5: Duplicate Crash Detection
**Objective**: Validate handling of duplicate crash signatures in same run

**Steps**:
1. Trigger workflow_dispatch with crash signature "Duplicate Test"
2. Immediately trigger again with same signature
3. Verify second trigger either:
   - Fails gracefully (branch already exists)
   - Uses a different branch name (timestamp-based uniqueness)

**Expected Result**: No orphaned branches, graceful error or uniqueness maintained

---

### Scenario 6: Secret Masking Validation
**Objective**: Verify no API keys are leaked in logs or PR bodies

**Steps**:
1. Trigger workflow with a valid ANTHROPIC_API_KEY secret
2. Inspect workflow logs for any unmasked API key
3. Verify PR body doesn't contain the API key
4. Check logs for common patterns (sk-ant-, ghp_)

**Expected Result**: No secrets in logs or PR, log-scan passes

---

## How to Run E2E Tests

### Prerequisites
- A GitHub repository (private or public) for testing
- ANTHROPIC_API_KEY secret configured
- `.github/workflows/crash-auto-fix-manual.yml` and `crash-auto-fix-dispatch.yml` installed
- Action reference set to test branch (e.g., `@sprint/crash-fix-action-v1`)

### Setup Test Repository
See [SETUP-CHECKLIST.md](SETUP-CHECKLIST.md)

### Run Individual Test Scenario

**Scenario 1: workflow_dispatch with Android NPE**
```bash
cd test/e2e
./run-scenario.sh 1

# Or manually via gh CLI:
gh workflow run crash-auto-fix-manual.yml \
  --repo owner/crash-fix-e2e-target \
  -f crash-id="e2e-scenario-1" \
  -f signature="NullPointerException in MainActivity.onCreate" \
  -f app-version="1.0.0" \
  -f stack-trace="$(jq -r .stack_trace < sample-payloads/sample-payload-android-npe.json)" \
  -f agent="claude"
```

**Scenario 2: repository_dispatch with iOS Crash**
```bash
# Prepare payload
PAYLOAD=$(jq -r '.' test/e2e/sample-payloads/sample-payload-ios-crash.json)

gh api repos/owner/crash-fix-e2e-target/dispatches \
  -f event_type=crash-detected \
  -f client_payload="$PAYLOAD"
```

### Run All Test Scenarios
```bash
cd test/e2e
./run-all-scenarios.sh
```

---

## Sample Payloads

The `sample-payloads/` directory contains example crash payloads ready for E2E testing:

### sample-payload-android-npe.json
Android NullPointerException crash scenario
- **Signature**: `NullPointerException in MainActivity.onCreate`
- **App**: Example Android app
- **Affected file**: `MainActivity.java` line 42
- **Use case**: Validate Android-specific stack trace parsing

### sample-payload-ios-crash.json
iOS runtime crash scenario
- **Signature**: `EXC_BAD_ACCESS in UIViewController`
- **App**: Example iOS app
- **Affected file**: `ViewController.swift`
- **Use case**: Validate iOS memory error handling

### sample-payload-web-error.json
Web/JavaScript error scenario
- **Signature**: `ReferenceError: data is not defined`
- **App**: Example web app
- **Affected file**: `app.js`
- **Use case**: Validate JavaScript error parsing

Each payload:
- Matches `crash-payload-schema.json` structure
- Contains realistic stack traces
- Is ready for immediate use in triggers

---

## Validating E2E Test Results

After each test run, verify:

### Workflow Execution
- [ ] Workflow status is green (success)
- [ ] All steps completed without timeouts
- [ ] Logs show no error messages

### PR Creation
- [ ] PR exists in test repository
- [ ] PR title includes crash signature
- [ ] PR branch is named `crash-fix/<slug>-<run-id>`
- [ ] PR body contains crash metadata table

### Code Changes
- [ ] PR diff shows only crash-related changes
- [ ] No unrelated files modified
- [ ] Fix is syntactically correct
- [ ] Fix addresses the crash root cause (not just symptoms)

### Security
- [ ] No API keys in logs
- [ ] No API keys in PR body
- [ ] Log-scan step passed
- [ ] No secrets in workflow output

### Agent Output
- [ ] Claude output is present in PR body
- [ ] Analysis is relevant to the crash
- [ ] Fix proposal makes sense

---

## Troubleshooting E2E Tests

### Workflow Fails: "Secret not found"
- Verify ANTHROPIC_API_KEY is set in test repo settings
- Check secret name matches exactly

### PR Not Created
- Check workflow logs for failures in steps 7-8 (push/PR creation)
- Verify test repo has write permissions
- Ensure no duplicate branch names exist

### Claude Output Missing
- Check step 5 logs (agent invocation)
- Verify Claude CLI was installed successfully
- Confirm ANTHROPIC_API_KEY is valid

### Secret Leaked in Logs
- Immediately revoke ANTHROPIC_API_KEY
- Generate new API key
- Re-add secret to GitHub
- Delete exposed workflow run

### Timeout During Test
- Increase job timeout in workflow file
- Use simpler crash payloads
- Check Claude API status
- Retry the test

---

## Continuous Integration

The E2E test suite can be integrated into CI/CD:

```yaml
# Example: Run E2E tests after code changes
name: E2E Tests
on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run E2E test scenarios
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TEST_REPO: owner/crash-fix-e2e-target
        run: |
          cd test/e2e
          ./run-all-scenarios.sh
      
      - name: Validate PR creation
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TEST_REPO: owner/crash-fix-e2e-target
        run: |
          # Check that PRs were created in test repo
          PR_COUNT=$(gh pr list --repo $TEST_REPO --limit 1 | wc -l)
          if [ $PR_COUNT -eq 0 ]; then
            echo "ERROR: No PRs created during E2E tests"
            exit 1
          fi
```

---

## Summary

The E2E test suite validates the crash-fix-gh-action in real GitHub environments through:

1. **Scenario-based testing**: Multiple crash types and trigger methods
2. **Realistic payloads**: Android, iOS, Web crash examples
3. **Comprehensive validation**: Workflow execution, PR creation, security
4. **Easy troubleshooting**: Clear error messages and debugging steps

For detailed test repository setup, see [SETUP-CHECKLIST.md](SETUP-CHECKLIST.md).
For integration patterns, see [INTEGRATION.md](../../INTEGRATION.md).
