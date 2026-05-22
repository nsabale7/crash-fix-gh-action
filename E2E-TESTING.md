# E2E Testing Guide: crash-fix-gh-action

## What is an E2E Test Repository?

An E2E (End-to-End) test repository is a separate GitHub repository used to validate the crash-fix-gh-action in a production-like environment. It allows you to:

- Test the action's complete workflow: from crash payload input through PR creation
- Verify integration with actual GitHub infrastructure (Actions, secrets, PRs)
- Safely trigger workflows without affecting the primary action repository
- Validate both trigger types (workflow_dispatch and repository_dispatch) against real GitHub APIs
- Ensure the action works correctly across different app types and crash scenarios

The test repository is independent of the action repository, allowing you to test changes in isolation and verify that the action can be used by external projects.

---

## Preconditions Before Running E2E Tests

### Repository Setup
- **GitHub Account**: You must have access to create or manage a GitHub repository
- **Repository Created**: A public or private GitHub repository exists (e.g., `crash-fix-e2e-target`)
- **Actions Enabled**: GitHub Actions is enabled in the test repository settings (Settings > Actions > Allow all actions)
- **Write Permissions**: You have `contents:write` and `pull-requests:write` permissions in the test repository

### Secrets Configuration
- **ANTHROPIC_API_KEY**: Set as a repository secret in GitHub (Settings > Secrets and variables > Actions)
  - Value: Your valid Anthropic API key (sk-ant-xxx)
  - Scope: Available to all workflows in the test repository
  - Example: `Settings > Secrets and variables > Actions > New repository secret > Name: ANTHROPIC_API_KEY`

### GitHub Token
- **GITHUB_TOKEN**: Built-in for same-repository workflows (available automatically in Actions)
- **Cross-Repository Testing**: If testing action invocations from external systems, use a Personal Access Token (PAT) with `repo` and `workflow` scopes

### Workflow Files Installation
Before triggering E2E tests, the test repository must have the demo workflows:
- `.github/workflows/crash-auto-fix-manual.yml` (workflow_dispatch trigger)
- `.github/workflows/crash-auto-fix-dispatch.yml` (repository_dispatch trigger)

---

## How to Set Up the Test Repository

### Step 1: Create or Clone Test Repository
```bash
# Option A: Create a new test repo
gh repo create crash-fix-e2e-target --public --source=. --description "E2E test target for crash-fix-gh-action"

# Option B: Use an existing repo
cd /path/to/existing-test-repo
```

### Step 2: Enable GitHub Actions
1. Go to Settings > Actions > General
2. Ensure "Allow all actions and reusable workflows" is selected
3. Save

### Step 3: Configure ANTHROPIC_API_KEY Secret
1. Go to Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Name: `ANTHROPIC_API_KEY`
4. Value: Paste your Anthropic API key
5. Click "Add secret"

Verification:
```bash
# Verify the secret is set (you won't see the value)
gh secret list --repo owner/crash-fix-e2e-target
# Expected output: ANTHROPIC_API_KEY  Updated <date>
```

### Step 4: Copy Workflow Files to Test Repository
```bash
# From the primary action repository
cp .github/workflows/crash-auto-fix-manual.yml /path/to/test-repo/.github/workflows/
cp .github/workflows/crash-auto-fix-dispatch.yml /path/to/test-repo/.github/workflows/

# Or manually in GitHub UI:
# 1. Go to test repo > Actions > New workflow > set up a workflow yourself
# 2. Copy contents of crash-auto-fix-manual.yml into the editor
# 3. Commit and repeat for crash-auto-fix-dispatch.yml
```

### Step 5: Update Action Reference
Edit both workflow files in the test repo to reference the action correctly:

**For feature branch testing (during development):**
```yaml
uses: nsabale7/crash-fix-gh-action@sprint/crash-fix-action-v1
```

**For released version:**
```yaml
uses: nsabale7/crash-fix-gh-action@v1  # or @main
```

### Step 6: Create a Sample Crash Scenario (Optional but Recommended)
Add a small Java/Kotlin crash scenario to the test repo for testing:

```bash
mkdir -p src/main/java/com/example/app
cat > src/main/java/com/example/app/MainActivity.java << 'EOF'
package com.example.app;

public class MainActivity {
    public void processUserData(String data) {
        // This will crash when data is null
        String result = data.toUpperCase();
    }
}
EOF
```

---

## How to Trigger E2E Tests

### Method 1: workflow_dispatch (Manual Trigger)

**Via GitHub Web UI:**
1. Go to test repository > Actions > crash-auto-fix-manual
2. Click "Run workflow" button
3. Fill in the form:
   - **crash-id**: `test-npe-001`
   - **signature**: `NullPointerException in MainActivity.processUserData`
   - **app-version**: `1.0.0`
   - **stack-trace**: (paste full stack trace, or use example below)
   - **device-info**: `Pixel 5, Android 12`
   - **agent**: `claude` (or another agent if configured)
4. Click "Run workflow"

**Via GitHub CLI:**
```bash
gh workflow run crash-auto-fix-manual.yml \
  --repo owner/crash-fix-e2e-target \
  -f crash-id=test-npe-001 \
  -f signature="NullPointerException in MainActivity.processUserData" \
  -f app-version="1.0.0" \
  -f stack-trace="$(cat sample-crash-stack.txt)" \
  -f device-info="Pixel 5, Android 12" \
  -f agent="claude"
```

**Via curl (requires GITHUB_TOKEN):**
```bash
curl -X POST https://api.github.com/repos/owner/crash-fix-e2e-target/actions/workflows/crash-auto-fix-manual.yml/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "main",
    "inputs": {
      "crash-id": "test-npe-001",
      "signature": "NullPointerException in MainActivity.processUserData",
      "app-version": "1.0.0",
      "stack-trace": "java.lang.NullPointerException\n  at com.example.app.MainActivity.processUserData(MainActivity.java:42)",
      "device-info": "Pixel 5, Android 12",
      "agent": "claude"
    }
  }'
```

### Method 2: repository_dispatch (Webhook Trigger)

**Via GitHub CLI:**
```bash
gh api repos/owner/crash-fix-e2e-target/dispatches \
  -f event_type=crash-detected \
  -f client_payload='{"crash_id":"test-npe-002","signature":"NullPointerException in MainActivity.processUserData","app_version":"1.0.0","stack_trace":"java.lang.NullPointerException\n  at com.example.app.MainActivity.processUserData(MainActivity.java:42)","device_info":"Pixel 5, Android 12"}'
```

**Via curl (requires GITHUB_TOKEN):**
```bash
curl -X POST https://api.github.com/repos/owner/crash-fix-e2e-target/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "crash-detected",
    "client_payload": {
      "crash_id": "test-npe-002",
      "signature": "NullPointerException in MainActivity.processUserData",
      "app_version": "1.0.0",
      "stack_trace": "java.lang.NullPointerException\n  at com.example.app.MainActivity.processUserData(MainActivity.java:42)",
      "device_info": "Pixel 5, Android 12"
    }
  }'
```

---

## Expected Behavior

When an E2E test is triggered successfully, you should observe:

### Workflow Execution
1. **Workflow Run Initiated**: GitHub Actions dashboard shows a new workflow run (yellow circle = in progress)
2. **Job Logs**: Click the run to see real-time logs:
   - "Checking out test repository..." (Step 1: Checkout)
   - "Creating branch crash-fix/..." (Step 2: Branch creation)
   - "Installing Claude CLI..." (Step 3: Agent installation)
   - "Building crash prompt..." (Step 4: Prompt generation)
   - "Running Claude agent..." (Step 5: Agent execution)
   - "Committing changes..." (Step 6: Commit)
   - "Pushing to crash-fix/..." (Step 7: Push)
   - "Opening pull request..." (Step 8: PR creation)

### Pull Request Creation
1. **PR Appears**: A new PR is created in the test repository with:
   - **Title**: Includes crash signature (e.g., "fix: NullPointerException in MainActivity.processUserData")
   - **Branch**: Named `crash-fix/<signature-slug>-<run-id>` (e.g., `crash-fix/nullpointerexception-in-mainactivity-12345`)
   - **Author**: The GitHub Actions bot (@actions)

### PR Content
1. **PR Body**: Contains a markdown table with:
   - Crash ID
   - Signature
   - App Version
   - Device Info
   - Occurrence Count (if provided)
   - Stack Trace
   - **Claude Agent Output** (fix summary and analysis)

2. **PR Diff**: Shows code changes made by Claude:
   - Only files implicated by the stack trace are modified
   - Changes are focused on fixing the crash (e.g., null checks, proper initialization)
   - No unrelated changes

### Success Indicators
- Workflow status: Green checkmark (success)
- PR merged or ready for review
- No errors in logs
- `git log` on the PR branch shows the commit from the action

---

## Troubleshooting E2E Test Failures

### Workflow Fails: "Secret ANTHROPIC_API_KEY not found"
**Cause**: The secret is not configured in the test repository settings.
**Solution**:
1. Go to Settings > Secrets and variables > Actions
2. Verify `ANTHROPIC_API_KEY` is listed
3. If missing, click "New repository secret" and add it
4. Rerun the workflow

### Workflow Fails: "Cannot push to remote (authentication error)"
**Cause**: The built-in GITHUB_TOKEN doesn't have sufficient permissions or is not available.
**Solution**:
1. Check workflow permissions in the test repo: Settings > Actions > General > Workflow permissions
2. Ensure "Read and write permissions" is selected
3. Verify the workflow file includes `permissions: { contents: write, pull-requests: write }`
4. Rerun the workflow

### Workflow Fails: "Claude CLI not found" or "Installation failed"
**Cause**: Claude CLI installation failed (network issue, Node version mismatch, etc.).
**Solution**:
1. Check logs for the exact error message
2. Verify Node.js is available: logs should show `node --version` output
3. Check that npm is accessible and updated
4. Ensure the action's `action/agents/claude/install.sh` is correct
5. Rerun with `--verbose` flag if available

### Workflow Fails: "Cannot create branch: already exists"
**Cause**: A previous run created a branch that was not deleted, and the action is trying to create the same branch again.
**Solution**:
1. Go to test repo > Branches
2. Delete the orphaned `crash-fix/*` branch
3. Rerun the workflow

### Workflow Fails: "No changes to commit"
**Cause**: Claude agent ran but made no changes (empty output or no-op fix).
**Solution**:
1. Check the agent output in the PR body or logs
2. Verify the stack trace and crash payload are valid
3. Try with a different, simpler crash scenario (e.g., sample-payload-android-npe.json)
4. Confirm ANTHROPIC_API_KEY is set and valid

### PR Not Created
**Cause**: Workflow completed but PR creation step failed.
**Solution**:
1. Check workflow logs for the exact failure point
2. Verify the branch was pushed: `gh branch list --repo owner/crash-fix-e2e-target`
3. Ensure `pull-requests: write` permission is enabled
4. Check for rate limiting (GitHub Actions has API call limits)

### Workflow Timeout
**Cause**: Claude agent took too long to respond (API latency, large stack trace, etc.).
**Solution**:
1. Increase timeout in the workflow file (if supported)
2. Use a simpler crash payload
3. Check Claude API status (https://status.anthropic.com)
4. Retry the workflow

### Secret Leaked in Logs
**Cause**: ANTHROPIC_API_KEY or other sensitive data appears in workflow logs.
**Solution**:
1. Immediately revoke the exposed secret: Settings > Secrets and variables > Actions > ANTHROPIC_API_KEY > Delete
2. Generate a new API key in Anthropic console
3. Re-add the secret to GitHub
4. Delete the workflow run logs (if available)
5. Do not commit or push any logs containing secrets

---

## Example E2E Test Scenario

Here's a complete walkthrough of a typical E2E test:

### Setup (One-time)
```bash
# Create test repo
gh repo create crash-fix-e2e-target --public

# Add secret
gh secret set ANTHROPIC_API_KEY --repo owner/crash-fix-e2e-target

# Add workflows
cp .github/workflows/crash-auto-fix-manual.yml crash-fix-e2e-target/.github/workflows/
cp .github/workflows/crash-auto-fix-dispatch.yml crash-fix-e2e-target/.github/workflows/
cd crash-fix-e2e-target && git add . && git commit -m "Add crash-fix workflows" && git push
```

### Run Test
```bash
# Trigger via dispatch
gh workflow run crash-auto-fix-manual.yml \
  --repo owner/crash-fix-e2e-target \
  -f crash-id=test-001 \
  -f signature="NullPointerException in MainActivity.onCreate" \
  -f app-version="1.0.0" \
  -f stack-trace="java.lang.NullPointerException\n  at com.example.MainActivity.onCreate(MainActivity.java:42)" \
  -f agent="claude"

# Wait for workflow to complete
sleep 30
gh run list --repo owner/crash-fix-e2e-target --limit 1

# Check PR
gh pr list --repo owner/crash-fix-e2e-target --limit 1
```

### Verify Results
```bash
# View PR details
gh pr view --repo owner/crash-fix-e2e-target 1

# Check diff
gh pr diff --repo owner/crash-fix-e2e-target 1

# Verify branch cleanup (if implemented)
gh branch list --repo owner/crash-fix-e2e-target
```

---

## Summary

E2E testing validates the crash-fix-gh-action in a real GitHub environment. Key points:

- **Test Repository**: A separate GitHub repo with ANTHROPIC_API_KEY secret configured
- **Trigger Methods**: workflow_dispatch (manual) or repository_dispatch (webhook)
- **Expected Output**: PR with crash details, proposed fix, and focused diff
- **Validation**: Check logs for errors, verify PR creation, inspect code changes
- **Troubleshooting**: Use workflow logs to diagnose failures; common issues are secret config, permissions, and CLI installation

For detailed integration guidance, see [INTEGRATION.md](INTEGRATION.md).
