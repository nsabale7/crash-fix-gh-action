#!/bin/bash
set -e

# Test: Input Handling & Prompt Building
# This script verifies that:
# 1. action.yml inputs are properly defined
# 2. Environment variables are correctly exported
# 3. action/build-prompt.sh correctly parses and builds prompts
# 4. Prompts are well-formed Markdown with all expected fields

echo "=== Task 2: Input Handling & Prompt Building Test ==="

# Test 1: Verify action.yml has all required inputs
echo ""
echo "Test 1: Verify action.yml input schema..."
if grep -q "crash-id:" action.yml && \
   grep -q "signature:" action.yml && \
   grep -q "app-version:" action.yml && \
   grep -q "stack-trace:" action.yml && \
   grep -q "agent:" action.yml && \
   grep -q "api-key:" action.yml && \
   grep -q "github-token:" action.yml; then
  echo "✓ PASS: All required inputs defined in action.yml"
else
  echo "✗ FAIL: Missing required inputs in action.yml"
  exit 1
fi

# Test 2: Load test fixtures and verify they are valid JSON
echo ""
echo "Test 2: Verify test fixtures are valid JSON..."
for fixture in test/fixtures/sample-crash-*.json; do
  if [ -f "$fixture" ]; then
    if jq empty "$fixture" 2>/dev/null; then
      echo "✓ PASS: $fixture is valid JSON"
    else
      echo "✗ FAIL: $fixture is not valid JSON"
      exit 1
    fi
  fi
done

# Test 3: Test build-prompt.sh with full crash payload
echo ""
echo "Test 3: Test build-prompt.sh with full crash payload..."
export CRASH_ID="crash-android-npe-001"
export SIGNATURE="NullPointerException: Attempt to invoke virtual method 'int java.lang.String.length()' on a null object reference"
export SUBTITLE="at com.example.app.MainActivity.onCreate"
export APP_VERSION="1.2.3"
export STACK_TRACE="java.lang.NullPointerException: Attempt to invoke virtual method 'int java.lang.String.length()' on a null object reference
  at com.example.app.MainActivity.onCreate(MainActivity.java:45)
  at android.app.Activity.performCreate(Activity.java:8080)"
export DEVICE_INFO="Pixel 4 | Android 12"
export OCCURRENCE_COUNT="142"
export CREATE_TIME="2026-05-19T10:30:00Z"

bash action/build-prompt.sh

PROMPT_FILE="/tmp/crash-fix-prompt.txt"
if [ -f "$PROMPT_FILE" ]; then
  echo "✓ PASS: Prompt file created"

  # Verify key sections are present
  if grep -q "# Crash Fix Task" "$PROMPT_FILE" && \
     grep -q "Crash Information" "$PROMPT_FILE" && \
     grep -q "Stack Trace" "$PROMPT_FILE" && \
     grep -q "Task" "$PROMPT_FILE"; then
    echo "✓ PASS: Prompt has all required sections"
  else
    echo "✗ FAIL: Prompt missing required sections"
    echo "--- Prompt Content ---"
    cat "$PROMPT_FILE"
    echo "--- End Prompt ---"
    exit 1
  fi

  # Verify values are included in prompt
  if grep -q "NullPointerException" "$PROMPT_FILE" && \
     grep -q "1.2.3" "$PROMPT_FILE" && \
     grep -q "Pixel 4" "$PROMPT_FILE"; then
    echo "✓ PASS: Prompt contains expected values"
  else
    echo "✗ FAIL: Prompt missing expected values"
    echo "--- Prompt Content ---"
    cat "$PROMPT_FILE"
    echo "--- End Prompt ---"
    exit 1
  fi

  # Verify prompt file is non-empty and readable
  if [ -s "$PROMPT_FILE" ]; then
    size=$(wc -c < "$PROMPT_FILE")
    echo "✓ PASS: Prompt file is non-empty ($size bytes)"
  else
    echo "✗ FAIL: Prompt file is empty"
    exit 1
  fi
else
  echo "✗ FAIL: Prompt file not created"
  exit 1
fi

# Test 4: Test build-prompt.sh with minimal crash payload (no optional fields)
echo ""
echo "Test 4: Test build-prompt.sh with minimal crash payload..."
unset SUBTITLE DEVICE_INFO OCCURRENCE_COUNT
export CRASH_ID="crash-minimal-001"
export SIGNATURE="IndexOutOfBoundsException: Index 5 out of bounds for length 3"
export APP_VERSION="2.0.0"
export STACK_TRACE=""
export CREATE_TIME="2026-05-19T12:00:00Z"

bash action/build-prompt.sh

if [ -f "$PROMPT_FILE" ]; then
  # Verify optional fields are omitted
  if ! grep -q "Pixel" "$PROMPT_FILE" && \
     ! grep -q "Occurrences" "$PROMPT_FILE"; then
    echo "✓ PASS: Minimal prompt correctly omits optional fields"
  else
    echo "✗ FAIL: Minimal prompt includes unexpected fields"
    cat "$PROMPT_FILE"
    exit 1
  fi

  # Verify required fields are present
  if grep -q "IndexOutOfBoundsException" "$PROMPT_FILE" && \
     grep -q "2.0.0" "$PROMPT_FILE"; then
    echo "✓ PASS: Minimal prompt contains required values"
  else
    echo "✗ FAIL: Minimal prompt missing required values"
    cat "$PROMPT_FILE"
    exit 1
  fi
else
  echo "✗ FAIL: Minimal prompt file not created"
  exit 1
fi

# Test 5: Verify action/pr-body-template.md has placeholder support
echo ""
echo "Test 5: Verify PR body template has placeholder support..."
if grep -q "{{SIGNATURE}}" action/pr-body-template.md && \
   grep -q "{{STACK_TRACE}}" action/pr-body-template.md && \
   grep -q "{{APP_VERSION}}" action/pr-body-template.md && \
   grep -q "{{AGENT_OUTPUT}}" action/pr-body-template.md; then
  echo "✓ PASS: PR body template has all required placeholders"
else
  echo "✗ FAIL: PR body template missing placeholders"
  exit 1
fi

# Test 6: Verify action/prompt-template.md exists and documents format
echo ""
echo "Test 6: Verify action/prompt-template.md documentation..."
if [ -f "action/prompt-template.md" ]; then
  if grep -q "Markdown format" action/prompt-template.md && \
     grep -q "Optional field omission" action/prompt-template.md; then
    echo "✓ PASS: Prompt template documentation is complete"
  else
    echo "✗ FAIL: Prompt template documentation is incomplete"
    exit 1
  fi
else
  echo "✗ FAIL: action/prompt-template.md not found"
  exit 1
fi

echo ""
echo "=== All Task 2 Tests Passed ==="
echo ""
echo "Summary:"
echo "✓ action.yml inputs properly defined"
echo "✓ Test fixtures created (sample-crash-android-npe.json, sample-crash-android-classcast.json, sample-crash-minimal.json)"
echo "✓ action/build-prompt.sh correctly parses env vars and builds prompts"
echo "✓ Prompts include all required sections (Crash Information, Stack Trace, Task)"
echo "✓ Optional fields are correctly omitted when not provided"
echo "✓ PR body template has all required placeholders"
echo "✓ Documentation provided (action/prompt-template.md)"
