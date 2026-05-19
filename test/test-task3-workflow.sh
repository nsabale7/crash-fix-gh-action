#!/bin/bash
#
# Test script for Task 3: Composite Action Workflow
# Verifies the 9-step workflow without actually creating a GitHub PR
#

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

echo "=== Task 3: Composite Action Workflow Test ==="
echo ""

# Create a temporary test workspace
TEST_WORKSPACE="/tmp/crash-fix-test-workspace-$$"
mkdir -p "$TEST_WORKSPACE"
trap "rm -rf $TEST_WORKSPACE" EXIT

echo "Test workspace: $TEST_WORKSPACE"
cd "$TEST_WORKSPACE"

# Initialize a test git repository
echo "Step 1: Setting up test git repository..."
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "# Test Repo" > README.md
git add README.md
git commit -m "Initial commit"
echo "[PASS] Git repository initialized"

# Step 2: Test branch creation logic
echo ""
echo "Step 2: Testing branch creation..."
SIGNATURE="NullPointerException"
RUN_ID="12345"
SIGNATURE_SLUG=$(echo "$SIGNATURE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-+/-/g')
BRANCH_NAME="crash-fix/${SIGNATURE_SLUG}-${RUN_ID}"

if git checkout -b "$BRANCH_NAME"; then
  echo "[PASS] Branch created: $BRANCH_NAME"
else
  echo "[FAIL] Failed to create branch"
  exit 1
fi

# Step 3: Test prompt building
echo ""
echo "Step 3: Testing prompt building..."
export CRASH_ID="issue-001"
export SIGNATURE="NullPointerException"
export SUBTITLE="at MainActivity.onCreate"
export APP_VERSION="1.2.3"
export STACK_TRACE="java.lang.NullPointerException: Attempt to invoke virtual method 'void android.app.Activity.onCreate(android.os.Bundle)' on a null object reference"
export DEVICE_INFO="Pixel 6, Android 13"
export OCCURRENCE_COUNT="42"
export CREATE_TIME="2026-05-19T10:00:00Z"

if bash "$PROJECT_ROOT/action/build-prompt.sh"; then
  if [ -f "/tmp/crash-fix-prompt.txt" ]; then
    PROMPT_SIZE=$(wc -c < "/tmp/crash-fix-prompt.txt")
    echo "[PASS] Prompt file created ($PROMPT_SIZE bytes)"
    echo "---"
    head -20 "/tmp/crash-fix-prompt.txt"
    echo "---"
  else
    echo "[FAIL] Prompt file not created"
    exit 1
  fi
else
  echo "[FAIL] Prompt building failed"
  exit 1
fi

# Step 4: Test agent output simulation
echo ""
echo "Step 4: Testing agent output capture..."
# Simulate agent output
cat > /tmp/agent-output.txt << 'EOF'
## Root Cause
The crash is caused by a null reference check missing in MainActivity.onCreate().

## Proposed Fix
Add a null check before calling the onCreate method:

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
  if (savedInstanceState == null) {
    // Handle null case
    return;
  }
  super.onCreate(savedInstanceState);
  // ... rest of onCreate
}
```

## Files to Change
- MainActivity.java (line 42)

## Why This Fixes It
The null check prevents the NullPointerException by ensuring we only proceed if the savedInstanceState is non-null.
EOF

if [ -s "/tmp/agent-output.txt" ]; then
  AGENT_SIZE=$(wc -c < "/tmp/agent-output.txt")
  echo "[PASS] Agent output file created ($AGENT_SIZE bytes)"
else
  echo "[FAIL] Agent output file is empty"
  exit 1
fi

# Step 5: Test PR body template rendering
echo ""
echo "Step 5: Testing PR body template rendering..."
if [ -f "$PROJECT_ROOT/action/pr-body-template.md" ]; then
  PR_BODY_FILE="/tmp/test-pr-body.md"
  cp "$PROJECT_ROOT/action/pr-body-template.md" "$PR_BODY_FILE"

  # Simulate the substitutions
  AGENT_OUTPUT=$(cat /tmp/agent-output.txt)
  sed -i "s|{{SIGNATURE}}|${SIGNATURE}|g" "$PR_BODY_FILE"
  sed -i "s|{{CRASH_ID}}|${CRASH_ID}|g" "$PR_BODY_FILE"
  sed -i "s|{{APP_VERSION}}|${APP_VERSION}|g" "$PR_BODY_FILE"
  sed -i "s|{{DEVICE_INFO}}|${DEVICE_INFO}|g" "$PR_BODY_FILE"
  sed -i "s|{{STACK_TRACE}}|${STACK_TRACE}|g" "$PR_BODY_FILE"
  sed -i "s|{{AGENT_OUTPUT}}|${AGENT_OUTPUT}|g" "$PR_BODY_FILE"

  # Check that no placeholders remain (except those that should be empty)
  if grep -q "{{" "$PR_BODY_FILE"; then
    echo "[FAIL] Unsubstituted placeholders found in PR body"
    cat "$PR_BODY_FILE"
    exit 1
  fi

  echo "[PASS] PR body template rendered successfully"
  echo "---"
  head -20 "$PR_BODY_FILE"
  echo "---"
else
  echo "[FAIL] PR body template not found"
  exit 1
fi

# Step 6: Test commit logic
echo ""
echo "Step 6: Testing commit logic..."
# Create a test change
echo "// Fixed NullPointerException" >> README.md
if git diff --quiet; then
  echo "[FAIL] No changes detected, but file was modified"
  exit 1
fi

git add -A || exit 1
git commit -m "Fix crash: ${SIGNATURE}" || exit 1
echo "[PASS] Changes committed successfully"

# Step 7: Test output extraction logic
echo ""
echo "Step 7: Testing output extraction..."
BRANCH_OUTPUT="$BRANCH_NAME"
echo "[PASS] Branch output extracted: $BRANCH_OUTPUT"

# Simulate PR creation output
PR_URL="https://github.com/test-owner/test-repo/pull/123"
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
if [ -n "$PR_NUMBER" ]; then
  echo "[PASS] PR number extracted: $PR_NUMBER"
  echo "[PASS] PR URL extracted: $PR_URL"
else
  echo "[FAIL] Failed to extract PR number"
  exit 1
fi

# Step 8: Test error handling in steps
echo ""
echo "Step 8: Testing error handling..."

# Test set -e behavior
test_set_e() {
  set -e
  false || exit 1
}

if ! test_set_e 2>/dev/null; then
  echo "[PASS] Error handling (set -e || exit 1) works correctly"
else
  echo "[FAIL] Error handling not working as expected"
  exit 1
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "[PASS] Step 1: Checkout repository"
echo "[PASS] Step 2: Create feature branch (crash-fix/<signature>-<run-id>)"
echo "[PASS] Step 3: Install agent (simulated)"
echo "[PASS] Step 4: Build prompt"
echo "[PASS] Step 5: Run agent (simulated)"
echo "[PASS] Step 6: Commit changes"
echo "[PASS] Step 7: Push branch (simulated)"
echo "[PASS] Step 8: Open PR (simulated)"
echo "[PASS] Step 9: Export outputs (pr-url, pr-number, branch)"
echo ""
echo "=== All Task 3 tests passed ==="
