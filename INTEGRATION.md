# Integration Guide: crash-fix-gh-action

This guide explains how to integrate the crash-fix-gh-action into your GitHub repositories and external systems.

---

## Quick Start: Add to Your Repository

### Step 1: Add Workflow Files
Copy the demo workflows to your repository's `.github/workflows/` directory:

```bash
# Manual trigger workflow
cp crash-auto-fix-manual.yml .github/workflows/

# Webhook trigger workflow
cp crash-auto-fix-dispatch.yml .github/workflows/

git add .github/workflows/
git commit -m "Add crash-fix workflows"
git push
```

### Step 2: Configure Secrets
In your GitHub repository, add the required secret:

1. Go to **Settings > Secrets and variables > Actions**
2. Click **New repository secret**
3. Add `ANTHROPIC_API_KEY` (your Anthropic API key)
4. Optionally add `AGENT_API_KEY` if using other agents (aider, codex, gemini)

### Step 3: Test the Workflow
Trigger a manual test:

```bash
gh workflow run crash-auto-fix-manual.yml \
  -f crash-id="test-001" \
  -f signature="MyException in Module.method" \
  -f app-version="1.0.0" \
  -f stack-trace="$(cat crash-trace.txt)" \
  -f agent="claude"
```

### Step 4: Review the PR
The action creates a pull request with the fix proposal. Review and merge if satisfied.

---

## Workflow Integration Patterns

### Pattern 1: Manual Trigger (workflow_dispatch)
Best for: Ad-hoc crash fixes, testing, manual investigation

**When to use**: A developer discovers a crash in logs and wants to investigate immediately.

**Workflow**:
```yaml
name: Fix Crash (Manual)
on:
  workflow_dispatch:
    inputs:
      signature:
        description: "Crash signature (e.g., NullPointerException in MainActivity)"
        required: true
      app-version:
        description: "App version where crash occurred"
        required: true
      create-time:
        description: "ISO 8601 timestamp of crash (e.g. 2026-05-19T10:00:00Z)"
        required: true
      stack-trace:
        description: "Full stack trace"
        required: false

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: nsabale7/crash-fix-gh-action@main
        with:
          crash-id:     ${{ github.run_id }}
          signature:    ${{ inputs.signature }}
          app-version:  ${{ inputs.app-version }}
          create-time:  ${{ inputs.create-time }}
          stack-trace:  ${{ inputs.stack-trace }}
          agent:        claude
          api-key:      ${{ secrets.ANTHROPIC_API_KEY }}   # ✅ passed as with: input
          github-token: ${{ secrets.GITHUB_TOKEN }}         # ✅ passed as with: input
```

**Trigger via web UI**: Actions tab > Select workflow > Run workflow

---

### Pattern 2: Webhook Trigger (repository_dispatch)
Best for: Automated crash detection from external services (Crashlytics, Sentry, etc.)

**When to use**: A crash monitoring service detects a new crash and automatically opens a fix PR.

**Workflow**:
```yaml
name: Fix Crash (Webhook)
on:
  repository_dispatch:
    types: [crash-detected]

jobs:
  fix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: nsabale7/crash-fix-gh-action@main
        with:
          crash-id:         ${{ github.event.client_payload.crash_id }}
          signature:        ${{ github.event.client_payload.signature }}
          app-version:      ${{ github.event.client_payload.app_version }}
          create-time:      ${{ github.event.client_payload.create_time }}
          stack-trace:      ${{ github.event.client_payload.stack_trace }}
          device-info:      ${{ github.event.client_payload.device_info }}
          agent:            ${{ github.event.client_payload.agent || 'claude' }}
          api-key:          ${{ secrets.ANTHROPIC_API_KEY }}   # ✅ passed as with: input
          github-token:     ${{ secrets.GITHUB_TOKEN }}         # ✅ passed as with: input
```

**Trigger via API**:
```bash
curl -X POST https://api.github.com/repos/owner/repo/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "crash-detected",
    "client_payload": {
      "crash_id": "crash-20250519-001",
      "signature": "NullPointerException in MainActivity",
      "app_version": "2.1.0",
      "stack_trace": "java.lang.NullPointerException\n  at ...",
      "device_info": "Pixel 5, Android 12"
    }
  }'
```

---

### Pattern 3: CI/CD Pipeline Integration
Best for: Automated crash detection during testing, nightly regression detection

**When to use**: Your CI pipeline discovers crashes in integration tests or staging builds.

**Example: GitHub Actions workflow triggered by test failures**:
```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: ./gradlew test

      - name: Parse crash logs
        if: failure()
        id: parse-crash
        run: |
          # Extract crash details from test output
          CRASH_SIGNATURE=$(grep -oP '(?<=Exception: )[^;]+' test-output.log | head -1)
          STACK_TRACE=$(cat test-output.log)
          echo "signature=$CRASH_SIGNATURE" >> $GITHUB_OUTPUT
          echo "stack-trace<<EOF" >> $GITHUB_OUTPUT
          echo "$STACK_TRACE" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Trigger crash fix
        if: steps.parse-crash.outputs.signature
        uses: octocat/dispatch-action@main
        with:
          repo: ${{ github.repository }}
          event_type: crash-detected
          client_payload: |
            {
              "crash_id": "ci-${{ github.run_id }}",
              "signature": "${{ steps.parse-crash.outputs.signature }}",
              "app_version": "${{ github.sha }}",
              "stack_trace": "${{ steps.parse-crash.outputs.stack-trace }}"
            }
```

---

## External Service Integration

### Crashlytics Webhook Integration

**Objective**: Automatically create fix PRs when Crashlytics detects a new crash.

#### Setup

1. **In your GitHub repository**, create a webhook receiver:
   - Use GitHub's API endpoint: `https://api.github.com/repos/owner/repo/dispatches`
   - Requires authentication via personal access token (PAT) or GitHub App

2. **In Firebase/Crashlytics Console**:
   - Go to Project Settings > Integrations
   - Add a Webhook:
     - Payload URL: Your webhook receiver endpoint
     - Events: New crash, regression
     - Payload format: Custom (see below)

3. **Webhook Payload Format** (from Crashlytics):
   ```json
   {
     "issue": {
       "id": "12345",
       "title": "NullPointerException in MainActivity",
       "subtitle": "at onCreate()",
       "appVersion": "2.1.0",
       "lastOccurrence": "2025-05-19T10:30:00Z",
       "occurrenceCount": 42,
       "state": "NEW"
     },
     "crashDetails": {
       "signature": "java.lang.NullPointerException",
       "stackTrace": "java.lang.NullPointerException\n  at com.example.MainActivity.onCreate(MainActivity.java:42)\n  ...",
       "deviceInfo": "Pixel 5, Android 12"
     }
   }
   ```

#### Implementation

Create a webhook receiver service (example: AWS Lambda, Vercel Function, or simple HTTP endpoint):

```python
# Example: Vercel Function (serverless)
import json
import subprocess
import os

def handler(request):
    if request.method != "POST":
        return {"error": "Method not allowed"}, 405

    payload = request.json
    issue = payload.get("issue", {})
    crash = payload.get("crashDetails", {})

    # Prepare dispatch payload
    dispatch_payload = {
        "event_type": "crash-detected",
        "client_payload": {
            "crash_id": f"crashlytics-{issue.get('id')}",
            "signature": crash.get("signature"),
            "app_version": issue.get("appVersion"),
            "stack_trace": crash.get("stackTrace"),
            "device_info": crash.get("deviceInfo"),
            "occurrence_count": issue.get("occurrenceCount"),
            "create_time": issue.get("lastOccurrence")
        }
    }

    # Call GitHub API
    result = subprocess.run([
        "curl", "-X", "POST",
        f"https://api.github.com/repos/owner/repo/dispatches",
        "-H", f"Authorization: token {os.getenv('GITHUB_TOKEN')}",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(dispatch_payload)
    ], capture_output=True, text=True)

    if result.returncode != 0:
        return {"error": result.stderr}, 500

    return {"status": "dispatched"}, 202
```

#### Trigger Workflow

Once the webhook dispatches the event, the `crash-auto-fix-dispatch.yml` workflow runs and creates a fix PR.

---

### Sentry Integration

**Objective**: Automatically create fix PRs for Sentry crash alerts.

#### Setup

1. **In Sentry**:
   - Go to Project > Integrations > WebHooks
   - Add a webhook with:
     - Payload URL: Your webhook receiver endpoint
     - Alert Rules: Configure which crashes trigger the webhook

2. **Sentry Webhook Payload** (example):
   ```json
   {
     "issue": {
       "id": "999",
       "title": "ReferenceError: undefined is not defined",
       "url": "https://sentry.io/issues/999/"
     },
     "event": {
       "message": "undefined is not defined",
       "tags": {"release": "1.2.3"},
       "platform": "javascript",
       "exception": {
         "values": [
           {
             "type": "ReferenceError",
             "value": "undefined is not defined",
             "stacktrace": {
               "frames": [...]
             }
           }
         ]
       }
     }
   }
   ```

3. **Webhook Receiver** (extract and dispatch to GitHub):
   ```python
   def sentry_handler(request):
       payload = request.json
       event = payload.get("event", {})
       issue = payload.get("issue", {})

       # Extract crash info from Sentry event
       exception = event.get("exception", {}).get("values", [{}])[0]
       stack_trace = format_sentry_stacktrace(exception.get("stacktrace"))

       dispatch_payload = {
           "event_type": "crash-detected",
           "client_payload": {
               "crash_id": f"sentry-{issue.get('id')}",
               "signature": f"{exception.get('type')}: {exception.get('value')}",
               "app_version": event.get("tags", {}).get("release", "unknown"),
               "stack_trace": stack_trace
           }
       }

       # Dispatch to GitHub
       return dispatch_to_github(dispatch_payload)
   ```

---

### Custom Monitoring Service Integration

**Objective**: Integrate with your internal crash monitoring service.

#### Implementation Pattern

1. **Your monitoring service** detects a crash and needs to trigger a fix PR
2. **Call the GitHub API**:
   ```bash
   curl -X POST https://api.github.com/repos/owner/repo/dispatches \
     -H "Authorization: token $PAT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "event_type": "crash-detected",
       "client_payload": {
         "crash_id": "your-internal-crash-id",
         "signature": "ExceptionType: message",
         "app_version": "x.y.z",
         "stack_trace": "full stack trace",
         "device_info": "optional device info"
       }
     }'
   ```

3. **Workflow runs** and creates a fix PR in your repository

---

## Team Workflow Integration

### Scenario: Crash Triage Workflow

1. **Crash is reported** (via Crashlytics, Sentry, or manual report)
2. **Webhook/manual trigger** invokes `crash-auto-fix-dispatch.yml`
3. **Action creates a PR** with Claude's fix proposal
4. **Team reviews the PR**:
   - If approved: Merge and deploy
   - If changes needed: Request review from Claude (re-run with feedback)
   - If dismissed: Close the PR and mark crash as wontfix

### Scenario: Automated Release Pipeline

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy
        run: ./scripts/deploy.sh

      - name: Run smoke tests
        run: ./scripts/smoke-tests.sh
        continue-on-error: true

      - name: Check for crashes in smoke tests
        if: failure()
        run: |
          # Extract crash from smoke test logs
          CRASH_INFO=$(./scripts/extract-crash.sh smoke-test.log)
          gh workflow run crash-auto-fix-manual.yml \
            -f crash-id="release-smoke-test" \
            -f signature="$(echo $CRASH_INFO | jq -r .signature)" \
            -f app-version="${{ github.ref }}" \
            -f stack-trace="$(echo $CRASH_INFO | jq -r .stackTrace)"
```

---

## Security Considerations for Integration

### 1. API Key Management
- **Never commit API keys** to repositories
- **Use GitHub Secrets** for ANTHROPIC_API_KEY and PAT tokens
- **Rotate keys regularly** (monthly or when exposed)
- **Use organization-level secrets** for multiple repositories

### 2. Webhook Security
- **Validate webhook signatures** if using third-party services (Crashlytics, Sentry)
  - Check X-Hub-Signature header for GitHub-sourced webhooks
  - Verify HMAC signature with your webhook secret
- **Use HTTPS** for all webhook endpoints
- **Restrict IP addresses** of webhook senders where possible

### 3. Permissions & Access
- **Minimize GitHub Actions permissions**: Use `contents:write, pull-requests:write` only
- **Use PAT tokens with minimal scopes**: `repo` for repo access, `workflow` for Actions
- **Audit access logs** regularly
- **Revoke unused tokens** immediately

### 4. Data Privacy
- **Do not log sensitive stack traces** in public repositories
- **Consider private repositories** for crash-fix workflows if crash data is sensitive
- **Redact API keys** in logs before sharing (GitHub secret-masking helps)
- **Be cautious with external webhook services** — review their privacy policies

### 5. Rate Limiting
- **GitHub API rate limits**: 5,000 requests per hour (per user/token)
- **Anthropic API rate limits**: Monitor your usage in the Anthropic dashboard
- **Implement backoff logic** for retrying failed dispatches
- **Batch crash fixes** during off-peak hours if high volume

### 6. PR Review Practices
- **Require human review** before merging fix PRs
- **Review diff carefully** — verify changes are crash-related only
- **Test the fix** in staging before merging to production
- **Monitor for false positives** — Claude may suggest incorrect fixes for ambiguous crashes

---

## Best Practices

### 1. Crash Payload Quality
- **Include full stack traces** (Claude needs context to fix correctly)
- **Provide app version** (helps narrow down causes)
- **Add device info** when available (platform, OS version, RAM)
- **Be specific with signatures** (include exception type and method name)

### 2. Workflow Naming
- **Use descriptive workflow names** for clarity in logs
- **Tag PRs consistently** (e.g., `crash-fix:`) for easy filtering
- **Include crash ID** in branch names for traceability

### 3. Testing Fixes
- **Run the fixed code** in your test environment before merging
- **Add regression tests** to prevent the same crash recurring
- **Monitor production** after merging to confirm fix is effective

### 4. Monitoring Integration
- **Set up alerts** for failed crash-fix workflows
- **Track fix success rates** (how many AI-generated fixes work vs. how many need revision)
- **Gather feedback** from team on Claude's fix quality

### 5. Scaling
- **Use multiple agents** (Claude, Aider, Codex) for different crash types
- **Implement crash de-duplication** to avoid duplicate fix PRs
- **Archive old crash PRs** to keep the repository clean

---

## Troubleshooting Integration Issues

### "repository_dispatch not working"
- Verify the workflow file has `on: { repository_dispatch: { types: [crash-detected] } }`
- Check the GitHub token has `repo` scope
- Verify the repository and event_type match exactly

### "Webhook receiver times out"
- Increase timeout in your receiver service
- Move webhook processing to async (queue, background job)
- Return HTTP 202 immediately and process dispatch asynchronously

### "Too many duplicate fix PRs"
- Implement crash deduplication in your webhook receiver
- Check if the crash signature already has an open PR
- Use a dedup key (e.g., hash of signature + version) to avoid duplicate triggers

### "Action fails with 'Cannot push to remote'"
- Verify `permissions: { contents: write }` is set in the workflow
- Check the GITHUB_TOKEN has write access (it should by default)
- Ensure the repository isn't a fork with restricted Actions

### "Workflow times out waiting for Claude"
- Increase the job timeout in the workflow (up to 6 hours)
- Use simpler crash payloads for faster processing
- Check Claude API status
- Consider using a faster agent (Codex) for large payloads

---

## Examples: Complete Integration

### Example 1: Crashlytics → GitHub Fix PR

```bash
# 1. Crashlytics webhook calls your receiver
POST https://your-webhook-service.com/crashlytics

# 2. Receiver parses payload and dispatches to GitHub
curl -X POST https://api.github.com/repos/myorg/myapp/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "crash-detected",
    "client_payload": {
      "crash_id": "crashlytics-12345",
      "signature": "NullPointerException in MainActivity.onCreate",
      "app_version": "2.1.0",
      "stack_trace": "java.lang.NullPointerException\n  at com.myapp.MainActivity.onCreate(MainActivity.java:42)"
    }
  }'

# 3. GitHub Actions runs crash-auto-fix-dispatch.yml
# 4. Action invokes crash-fix-gh-action composite action
# 5. Claude CLI investigates and suggests a fix
# 6. Action opens a PR: "fix: NullPointerException in MainActivity.onCreate"
# 7. Team reviews and merges the PR
```

### Example 2: Manual Trigger During On-Call Shift

```bash
# Developer sees crash in logs and runs:
gh workflow run crash-auto-fix-manual.yml \
  -f crash-id="oncall-20250519-001" \
  -f signature="IndexOutOfBoundsException in Utils.process" \
  -f app-version="2.0.5" \
  -f stack-trace="$(cat /tmp/crash.txt)" \
  -f agent="claude"

# Workflow runs, Claude suggests a fix
# Developer reviews the PR and merges if satisfied
# If not satisfied, they can run again with more context
```

---

## Common Mistakes

### Mistake 1: Passing `api-key` as an environment variable instead of a `with:` input

**What it looks like (WRONG):**
```yaml
steps:
  - uses: nsabale7/crash-fix-gh-action@main
    with:
      crash-id: abc123
      signature: NullPointerException
      app-version: 1.0.0
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}  # ❌ wrong
```

**Error you'll see:**
```
Error: Input required and not supplied: api-key
```
or
```
Error: AGENT_API_KEY is not set. Pass api-key as a with: input, not as an env var.
```

**Why this happens:** The action reads `api-key` from the `with:` block via `${{ inputs.api-key }}`. Setting `ANTHROPIC_API_KEY` as an `env:` variable bypasses this entirely — `inputs.api-key` will be empty, and the action will fail at the validation step before the agent ever runs.

**Fix:**
```yaml
steps:
  - uses: nsabale7/crash-fix-gh-action@main
    with:
      crash-id:  abc123
      signature: NullPointerException
      app-version: 1.0.0
      create-time: "2026-05-19T10:00:00Z"
      api-key:      ${{ secrets.ANTHROPIC_API_KEY }}   # ✅ correct
      github-token: ${{ secrets.GITHUB_TOKEN }}         # ✅ correct
```

---

### Mistake 2: Omitting `github-token` from `with:` inputs

**What it looks like (WRONG):**
```yaml
steps:
  - uses: nsabale7/crash-fix-gh-action@main
    with:
      crash-id:  abc123
      signature: NullPointerException
      app-version: 1.0.0
      create-time: "2026-05-19T10:00:00Z"
      api-key: ${{ secrets.ANTHROPIC_API_KEY }}
      # ❌ github-token is missing — branch push and PR creation will fail
```

**Error you'll see:**
```
Error: Input required and not supplied: github-token
```

**Fix:** Always include `github-token: ${{ secrets.GITHUB_TOKEN }}` in the `with:` block.

---

### Mistake 3: Omitting `create-time` (required field)

`create-time` is a required input. Omitting it causes the action's input validation step to fail before any agent work begins.

**Error you'll see:**
```
ERROR: Missing required input: create-time
```

**Fix:** Always supply `create-time` as an ISO 8601 timestamp:
```yaml
create-time: "2026-05-19T10:00:00Z"
```

For `workflow_dispatch`, add it as a required input in the trigger definition so callers must provide it:
```yaml
on:
  workflow_dispatch:
    inputs:
      create-time:
        description: "ISO 8601 timestamp of when the crash occurred"
        required: true
        type: string
```

---

## Summary

Integration patterns for crash-fix-gh-action:

1. **Automated**: Webhook from Crashlytics/Sentry → GitHub Actions → Fix PR
2. **Manual**: Developer triggers workflow → Claude investigates → Fix PR
3. **CI/CD**: Test failures detect crash → Automatically trigger fix workflow
4. **Custom**: Integrate with your internal monitoring service via webhook receiver

Each pattern enables rapid, AI-assisted crash fixing with human oversight.

For detailed E2E testing instructions, see [E2E-TESTING.md](E2E-TESTING.md).
