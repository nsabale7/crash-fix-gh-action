# E2E Test Repository Setup Checklist

This checklist guides you through setting up a test repository for E2E testing of crash-fix-gh-action.

---

## Pre-Setup Verification

- [ ] **GitHub Account**: You have a GitHub account with organization/owner access
- [ ] **Repository Access**: You can create new repositories or have write access to an existing test repo
- [ ] **API Access**: You have a personal access token (PAT) with `repo` and `workflow` scopes, or can use GitHub CLI (`gh auth`)
- [ ] **API Keys**: You have a valid ANTHROPIC_API_KEY from Anthropic console
- [ ] **Network Access**: You can access GitHub API endpoints and make HTTPS requests

---

## Step 1: Create or Identify Test Repository

### Option A: Create New Repository
```bash
# Using GitHub CLI
gh repo create crash-fix-e2e-target \
  --public \
  --description "E2E test target for crash-fix-gh-action" \
  --gitignore=None

# Verify creation
gh repo view owner/crash-fix-e2e-target
```

**Checkpoint**:
- [ ] Repository exists at `github.com/owner/crash-fix-e2e-target`
- [ ] Repository is accessible (public or you have access)
- [ ] Repository has `main` branch

### Option B: Use Existing Repository
```bash
# Navigate to your test repository
cd /path/to/existing-test-repo

# Verify it's a valid GitHub repo
git remote -v
# Should show origin pointing to GitHub
```

**Checkpoint**:
- [ ] Existing repository is accessible and has write permissions
- [ ] Repository has `main` branch or preferred default branch

---

## Step 2: Enable GitHub Actions

### In GitHub Web UI
1. Go to your test repository
2. Click **Settings**
3. In the left sidebar, click **Actions** > **General**
4. Under "Actions permissions", select **"Allow all actions and reusable workflows"**
5. Click **Save**

### Verification
```bash
# Check Actions are enabled (no error should be returned)
gh api repos/owner/crash-fix-e2e-target/actions/permissions
```

**Checkpoint**:
- [ ] GitHub Actions is enabled
- [ ] Workflow permissions are set to "Allow all actions"

---

## Step 3: Configure ANTHROPIC_API_KEY Secret

### Via GitHub CLI
```bash
# Set the secret
gh secret set ANTHROPIC_API_KEY \
  --repo owner/crash-fix-e2e-target \
  --body "sk-ant-xxx..."  # Paste your actual API key

# Verify it's set (won't show the value)
gh secret list --repo owner/crash-fix-e2e-target
# Expected: ANTHROPIC_API_KEY    Updated <date>
```

### Via GitHub Web UI
1. Go to your test repository > **Settings**
2. In the left sidebar, click **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. **Name**: `ANTHROPIC_API_KEY`
5. **Secret**: Paste your Anthropic API key (e.g., `sk-ant-xxxxxxxxxxxx`)
6. Click **Add secret**

### Verification
```bash
# Manually verify you can see the secret in Settings
# (The gh CLI won't show the value, but will confirm it exists)
gh secret list --repo owner/crash-fix-e2e-target | grep ANTHROPIC_API_KEY
# Should return: ANTHROPIC_API_KEY    Updated <timestamp>
```

**Checkpoint**:
- [ ] ANTHROPIC_API_KEY secret is set
- [ ] Secret is visible in Settings > Secrets and variables > Actions
- [ ] Secret is not visible in the gh CLI value output (expected for security)

---

## Step 4: Create .github/workflows Directory

```bash
cd /path/to/test-repo

# Create directory structure
mkdir -p .github/workflows

# Verify
ls -la .github/workflows/
```

**Checkpoint**:
- [ ] `.github/workflows/` directory exists

---

## Step 5: Copy Workflow Files

Copy the demo workflows from the action repository to your test repository:

```bash
# From action repo directory
cp .github/workflows/crash-auto-fix-manual.yml /path/to/test-repo/.github/workflows/
cp .github/workflows/crash-auto-fix-dispatch.yml /path/to/test-repo/.github/workflows/

# Verify
ls /path/to/test-repo/.github/workflows/
# Expected output:
# crash-auto-fix-manual.yml
# crash-auto-fix-dispatch.yml
```

### Verify Workflow Content
```bash
# Check workflow_dispatch is present
grep "workflow_dispatch" /path/to/test-repo/.github/workflows/crash-auto-fix-manual.yml
# Should show: on: workflow_dispatch:

# Check repository_dispatch is present
grep "repository_dispatch" /path/to/test-repo/.github/workflows/crash-auto-fix-dispatch.yml
# Should show: on: repository_dispatch:
```

**Checkpoint**:
- [ ] `crash-auto-fix-manual.yml` exists
- [ ] `crash-auto-fix-dispatch.yml` exists
- [ ] Both files contain valid workflow triggers

---

## Step 6: Update Action Reference in Workflows

Edit the workflow files to reference the correct action version.

### For Feature Branch Testing (During Development)
```bash
cd /path/to/test-repo

# Update action reference in both workflows to point to the feature branch
sed -i 's/uses: nsabale7\/crash-fix-gh-action@main/uses: nsabale7\/crash-fix-gh-action@sprint\/crash-fix-action-v1/g' \
  .github/workflows/crash-auto-fix-manual.yml \
  .github/workflows/crash-auto-fix-dispatch.yml

# Verify the change
grep "uses: nsabale7" .github/workflows/crash-auto-fix-manual.yml
# Should show: uses: nsabale7/crash-fix-gh-action@sprint/crash-fix-action-v1
```

### For Released Version
```bash
# Use main or a specific version tag
sed -i 's/uses: nsabale7\/crash-fix-gh-action@.*$/uses: nsabale7\/crash-fix-gh-action@main/g' \
  .github/workflows/crash-auto-fix-manual.yml \
  .github/workflows/crash-auto-fix-dispatch.yml
```

**Checkpoint**:
- [ ] Action reference in `crash-auto-fix-manual.yml` is correct
- [ ] Action reference in `crash-auto-fix-dispatch.yml` is correct
- [ ] References point to desired branch/version

---

## Step 7: Commit and Push Workflow Files

```bash
cd /path/to/test-repo

# Stage files
git add .github/workflows/

# Commit
git commit -m "Add crash-fix workflows for E2E testing"

# Push to main branch
git push origin main

# Verify on GitHub
gh repo view owner/crash-fix-e2e-target --web  # Opens in browser
# Check: Files are visible under .github/workflows/
```

**Checkpoint**:
- [ ] Workflow files are committed and pushed
- [ ] Files are visible on GitHub in `.github/workflows/` folder
- [ ] No uncommitted changes remain

---

## Step 8: Create Sample Crash Scenario (Optional)

Create a simple crash-prone scenario in the test repo:

```bash
cd /path/to/test-repo

# Create a sample Android crash
mkdir -p src/main/java/com/example/crash
cat > src/main/java/com/example/crash/CrashSample.java << 'EOF'
package com.example.crash;

public class CrashSample {
    /**
     * This method will crash with NullPointerException when data is null
     */
    public static String processData(String data) {
        // Null pointer crash: data.toUpperCase() when data is null
        return data.toUpperCase();
    }

    /**
     * This method will crash with ArrayIndexOutOfBoundsException
     */
    public static String getItem(String[] items, int index) {
        // Array index out of bounds crash
        return items[index];
    }
}
EOF

# Create a README documenting the crash scenarios
cat > CRASH-SCENARIOS.md << 'EOF'
# Crash Scenarios for E2E Testing

## Scenario 1: NullPointerException in CrashSample.processData

**Signature**: `NullPointerException in CrashSample.processData`

**Stack Trace**:
```
java.lang.NullPointerException
  at com.example.crash.CrashSample.processData(CrashSample.java:11)
  at com.example.app.MainActivity.onClick(MainActivity.java:42)
```

**Fix**: Add null check before calling toUpperCase()

## Scenario 2: ArrayIndexOutOfBoundsException in CrashSample.getItem

**Signature**: `ArrayIndexOutOfBoundsException in CrashSample.getItem`

**Stack Trace**:
```
java.lang.ArrayIndexOutOfBoundsException: index 10 out of bounds for length 5
  at com.example.crash.CrashSample.getItem(CrashSample.java:19)
  at com.example.app.ListAdapter.onBindViewHolder(ListAdapter.java:100)
```

**Fix**: Add bounds check before array access
EOF

# Commit
git add src/ CRASH-SCENARIOS.md
git commit -m "Add sample crash scenarios for E2E testing"
git push origin main
```

**Checkpoint** (Optional):
- [ ] Sample crash scenario files exist
- [ ] CRASH-SCENARIOS.md documents expected crashes
- [ ] Files are committed and pushed

---

## Validation Checklist

Run these checks to verify your test repository is ready:

### Check 1: Repository Access
```bash
gh repo view owner/crash-fix-e2e-target

# Expected: Repository details displayed
```
- [ ] Repository is accessible
- [ ] You have access to Settings and Secrets

### Check 2: GitHub Actions Enabled
```bash
gh api repos/owner/crash-fix-e2e-target/actions/permissions

# Expected: JSON output with actions_enabled: true
```
- [ ] Actions are enabled

### Check 3: Secret Configured
```bash
gh secret list --repo owner/crash-fix-e2e-target

# Expected: ANTHROPIC_API_KEY listed with timestamp
```
- [ ] ANTHROPIC_API_KEY is set

### Check 4: Workflow Files Exist
```bash
gh api repos/owner/crash-fix-e2e-target/contents/.github/workflows

# Expected: Array with crash-auto-fix-manual.yml and crash-auto-fix-dispatch.yml
```
- [ ] Both workflow files are present on GitHub

### Check 5: Workflow Files Are Valid YAML
```bash
# Download and validate locally
gh api repos/owner/crash-fix-e2e-target/contents/.github/workflows/crash-auto-fix-manual.yml \
  --jq '.content | @base64d' | head -20

# Expected: Valid YAML structure visible
```
- [ ] Workflow files are valid YAML
- [ ] action reference is correct

---

## First E2E Test Run Instructions

Once setup is complete, run your first E2E test:

### Option 1: Manual Trigger (workflow_dispatch)

**Via GitHub Web UI:**
1. Go to `github.com/owner/crash-fix-e2e-target`
2. Click **Actions** tab
3. Select **Fix Crash (Manual)** workflow
4. Click **Run workflow** button
5. Fill in form:
   - **crash-id**: `test-001`
   - **signature**: `NullPointerException in CrashSample.processData`
   - **app-version**: `1.0.0`
   - **stack-trace**: `java.lang.NullPointerException\n  at com.example.crash.CrashSample.processData(CrashSample.java:11)`
   - **agent**: `claude`
6. Click **Run workflow**

**Via GitHub CLI:**
```bash
gh workflow run crash-auto-fix-manual.yml \
  --repo owner/crash-fix-e2e-target \
  -f crash-id="test-001" \
  -f signature="NullPointerException in CrashSample.processData" \
  -f app-version="1.0.0" \
  -f stack-trace="java.lang.NullPointerException
  at com.example.crash.CrashSample.processData(CrashSample.java:11)" \
  -f agent="claude"
```

### Option 2: Webhook Trigger (repository_dispatch)

```bash
gh api repos/owner/crash-fix-e2e-target/dispatches \
  -f event_type=crash-detected \
  -f client_payload='{"crash_id":"test-002","signature":"NullPointerException in CrashSample.processData","app_version":"1.0.0","stack_trace":"java.lang.NullPointerException\n  at com.example.crash.CrashSample.processData(CrashSample.java:11)"}'
```

### Monitor Workflow Execution
```bash
# Watch workflow in real-time
gh run watch -R owner/crash-fix-e2e-target

# Or check status
gh run list --repo owner/crash-fix-e2e-target --limit 1
```

### Verify Results
```bash
# Check if PR was created
gh pr list --repo owner/crash-fix-e2e-target --limit 1

# View PR details
gh pr view --repo owner/crash-fix-e2e-target 1

# View PR diff
gh pr diff --repo owner/crash-fix-e2e-target 1
```

**Checkpoint** (After first run):
- [ ] Workflow runs appear in Actions tab
- [ ] Workflow completes without errors
- [ ] PR is created in test repository
- [ ] PR title includes crash signature
- [ ] PR body contains crash metadata
- [ ] PR diff shows fix proposal

---

## Post-Setup Maintenance

### Regular Tasks
- [ ] Monitor workflow runs for errors (weekly)
- [ ] Update ANTHROPIC_API_KEY if rotated
- [ ] Clean up old PRs/branches periodically
- [ ] Keep workflow files in sync with main action repo

### Cleanup
```bash
# Delete old PRs (if any)
gh pr list --repo owner/crash-fix-e2e-target --state merged | awk '{print $1}' | xargs -I {} \
  gh api repos/owner/crash-fix-e2e-target/pulls/{} -X DELETE

# Delete stale branches
git branch -r | grep "crash-fix/" | xargs git push origin --delete
```

---

## Troubleshooting Setup

### "Repository creation failed"
- Verify GitHub account has permissions to create repositories
- Check organization settings if creating in an org

### "Secret set command failed"
- Verify API token has `repo:write` scope
- Check secret name format (must be alphanumeric + underscore)

### "Workflow files not found on GitHub"
- Verify files are committed: `git status`
- Verify branch is pushed: `git log`
- Wait a moment for GitHub to sync (usually instant)

### "Workflow trigger doesn't appear in Actions tab"
- Verify workflow file is in `.github/workflows/` (exact path)
- Verify workflow file is valid YAML: `actionlint .github/workflows/crash-auto-fix-manual.yml`
- Wait a few moments for GitHub to index the workflow

### "Secret not available in workflow"
- Verify secret is set: `gh secret list --repo owner/crash-fix-e2e-target`
- Verify secret name matches in workflow: `${{ secrets.ANTHROPIC_API_KEY }}`
- Verify workflow has access to secrets (permissions set)

---

## Summary

Your test repository is ready for E2E testing when:

- [ ] Repository exists and is accessible
- [ ] GitHub Actions is enabled
- [ ] ANTHROPIC_API_KEY secret is configured
- [ ] Workflow files are installed in `.github/workflows/`
- [ ] Action reference points to correct branch/version
- [ ] First test run completes successfully with PR creation

For detailed E2E test instructions, see [README.md](README.md).
For integration guidance, see [INTEGRATION.md](../../INTEGRATION.md).
