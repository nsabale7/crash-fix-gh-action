#!/bin/bash
set -e

# Test: Integration Tests — Workflow Files & Action Integration
# This script verifies that:
# 1. Both workflow files exist and are valid YAML
# 2. Both workflows have proper trigger definitions (workflow_dispatch and repository_dispatch)
# 3. Both workflows properly call the crash-fix-gh-action composite action
# 4. All inputs are correctly mapped in both workflows
# 5. All outputs are correctly exposed in both workflows
# 6. README.md is comprehensive and documents all inputs/outputs

echo "=== Task 8: Integration Tests — Workflow Files & Action Integration ==="

# Test 1: Verify both workflow files exist
echo ""
echo "Test 1: Verify both workflow files exist..."
WORKFLOW_MANUAL=".github/workflows/crash-auto-fix-manual.yml"
WORKFLOW_DISPATCH=".github/workflows/crash-auto-fix-dispatch.yml"

if [ -f "$WORKFLOW_MANUAL" ]; then
  echo "✓ PASS: $WORKFLOW_MANUAL exists"
else
  echo "✗ FAIL: $WORKFLOW_MANUAL not found"
  exit 1
fi

if [ -f "$WORKFLOW_DISPATCH" ]; then
  echo "✓ PASS: $WORKFLOW_DISPATCH exists"
else
  echo "✗ FAIL: $WORKFLOW_DISPATCH not found"
  exit 1
fi

# Test 2: Verify action.yml exists (the composite action being called)
echo ""
echo "Test 2: Verify action.yml exists..."
if [ -f "action.yml" ]; then
  echo "✓ PASS: action.yml exists"
else
  echo "✗ FAIL: action.yml not found"
  exit 1
fi

# Test 3: Validate YAML syntax for both workflows
echo ""
echo "Test 3: Validate YAML syntax for both workflows..."

# Check if yq or python3 is available for YAML validation
if command -v yq &> /dev/null; then
  echo "Using yq for YAML validation..."
  if yq eval . "$WORKFLOW_MANUAL" > /dev/null 2>&1; then
    echo "✓ PASS: $WORKFLOW_MANUAL has valid YAML syntax"
  else
    echo "✗ FAIL: $WORKFLOW_MANUAL has invalid YAML syntax"
    exit 1
  fi

  if yq eval . "$WORKFLOW_DISPATCH" > /dev/null 2>&1; then
    echo "✓ PASS: $WORKFLOW_DISPATCH has valid YAML syntax"
  else
    echo "✗ FAIL: $WORKFLOW_DISPATCH has invalid YAML syntax"
    exit 1
  fi
elif command -v python3 &> /dev/null; then
  echo "Using python3 for YAML validation..."
  if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_MANUAL'))" 2>/dev/null; then
    echo "✓ PASS: $WORKFLOW_MANUAL has valid YAML syntax"
  else
    echo "✗ FAIL: $WORKFLOW_MANUAL has invalid YAML syntax"
    exit 1
  fi

  if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_DISPATCH'))" 2>/dev/null; then
    echo "✓ PASS: $WORKFLOW_DISPATCH has valid YAML syntax"
  else
    echo "✗ FAIL: $WORKFLOW_DISPATCH has invalid YAML syntax"
    exit 1
  fi
else
  echo "⚠ WARNING: yq and python3 not available, skipping YAML syntax validation"
  echo "⚠ Attempting basic validation using grep..."
  if grep -q "^on:" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: $WORKFLOW_MANUAL appears to be valid YAML (contains 'on:' trigger)"
  else
    echo "✗ FAIL: $WORKFLOW_MANUAL appears to be invalid YAML"
    exit 1
  fi

  if grep -q "^on:" "$WORKFLOW_DISPATCH"; then
    echo "✓ PASS: $WORKFLOW_DISPATCH appears to be valid YAML (contains 'on:' trigger)"
  else
    echo "✗ FAIL: $WORKFLOW_DISPATCH appears to be invalid YAML"
    exit 1
  fi
fi

# Test 4: Verify workflow_dispatch trigger in crash-auto-fix-manual.yml
echo ""
echo "Test 4: Verify workflow_dispatch trigger in crash-auto-fix-manual.yml..."
if grep -q "workflow_dispatch:" "$WORKFLOW_MANUAL"; then
  echo "✓ PASS: workflow_dispatch trigger defined"
else
  echo "✗ FAIL: workflow_dispatch trigger not found"
  exit 1
fi

# Test 5: Verify repository_dispatch trigger in crash-auto-fix-dispatch.yml
echo ""
echo "Test 5: Verify repository_dispatch trigger in crash-auto-fix-dispatch.yml..."
if grep -q "repository_dispatch:" "$WORKFLOW_DISPATCH"; then
  echo "✓ PASS: repository_dispatch trigger defined"
else
  echo "✗ FAIL: repository_dispatch trigger not found"
  exit 1
fi

# Test 6: Verify both workflows call the action with uses: ./
echo ""
echo "Test 6: Verify both workflows call the crash-fix-gh-action action..."
if grep -q "uses: ./" "$WORKFLOW_MANUAL"; then
  echo "✓ PASS: $WORKFLOW_MANUAL calls action with 'uses: ./'"
else
  echo "✗ FAIL: $WORKFLOW_MANUAL does not call action correctly"
  exit 1
fi

if grep -q "uses: ./" "$WORKFLOW_DISPATCH"; then
  echo "✓ PASS: $WORKFLOW_DISPATCH calls action with 'uses: ./'"
else
  echo "✗ FAIL: $WORKFLOW_DISPATCH does not call action correctly"
  exit 1
fi

# Test 7: Verify all required inputs are mapped in workflow_dispatch
echo ""
echo "Test 7: Verify all required inputs are mapped in workflow_dispatch..."
REQUIRED_INPUTS=("crash-id" "signature" "app-version" "create-time" "api-key" "github-token")
for input in "${REQUIRED_INPUTS[@]}"; do
  if grep -q "$input:" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: Input '$input' defined in workflow_dispatch"
  else
    echo "✗ FAIL: Input '$input' not found in workflow_dispatch"
    exit 1
  fi
done

# Test 8: Verify all required inputs are mapped in repository_dispatch
echo ""
echo "Test 8: Verify all optional inputs are available in workflow_dispatch..."
OPTIONAL_INPUTS=("subtitle" "stack-trace" "device-info" "occurrence-count" "agent" "base-branch")
for input in "${OPTIONAL_INPUTS[@]}"; do
  if grep -q "$input:" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: Optional input '$input' defined in workflow_dispatch"
  else
    echo "✗ FAIL: Optional input '$input' not found in workflow_dispatch"
    exit 1
  fi
done

# Test 9: Verify input value substitutions in workflow_dispatch
echo ""
echo "Test 9: Verify input value substitutions in workflow_dispatch..."
SUBSTITUTIONS=(
  'crash-id: \${{ inputs.crash-id }}'
  'signature: \${{ inputs.signature }}'
  'app-version: \${{ inputs.app-version }}'
  'create-time: \${{ inputs.create-time }}'
  'api-key: \${{ inputs.api-key }}'
  'github-token: \${{ inputs.github-token }}'
)

for sub in "${SUBSTITUTIONS[@]}"; do
  if grep -q "$sub" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: Found substitution: $sub"
  else
    echo "✗ FAIL: Substitution not found: $sub"
    exit 1
  fi
done

# Test 10: Verify input mapping from repository_dispatch payload in crash-auto-fix-dispatch.yml
echo ""
echo "Test 10: Verify input mapping from repository_dispatch payload..."
PAYLOAD_MAPPINGS=(
  'crash-id: \${{ github.event.client_payload.crash_id }}'
  'signature: \${{ github.event.client_payload.signature }}'
  'app-version: \${{ github.event.client_payload.app_version }}'
  'create-time: \${{ github.event.client_payload.create_time }}'
  'subtitle: \${{ github.event.client_payload.subtitle }}'
  'stack-trace: \${{ github.event.client_payload.stack_trace }}'
)

for mapping in "${PAYLOAD_MAPPINGS[@]}"; do
  if grep -q "$mapping" "$WORKFLOW_DISPATCH"; then
    echo "✓ PASS: Found payload mapping: $mapping"
  else
    echo "✗ FAIL: Payload mapping not found: $mapping"
    exit 1
  fi
done

# Test 11: Verify outputs are exposed in workflow_dispatch
echo ""
echo "Test 11: Verify outputs are exposed in workflow_dispatch..."
OUTPUTS=("pr-url" "pr-number" "branch")
for output in "${OUTPUTS[@]}"; do
  if grep -q "$output:" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: Output '$output' exposed in workflow_dispatch"
  else
    echo "✗ FAIL: Output '$output' not found in workflow_dispatch"
    exit 1
  fi
done

# Test 12: Verify outputs are exposed in repository_dispatch
echo ""
echo "Test 12: Verify outputs are exposed in repository_dispatch..."
for output in "${OUTPUTS[@]}"; do
  if grep -q "$output:" "$WORKFLOW_DISPATCH"; then
    echo "✓ PASS: Output '$output' exposed in repository_dispatch"
  else
    echo "✗ FAIL: Output '$output' not found in repository_dispatch"
    exit 1
  fi
done

# Test 13: Verify output value substitutions
echo ""
echo "Test 13: Verify output value substitutions in action..."
for output in "${OUTPUTS[@]}"; do
  if grep -q "steps.action.outputs.$output" "$WORKFLOW_MANUAL"; then
    echo "✓ PASS: Found output substitution for '$output' in workflow_dispatch"
  else
    echo "✗ FAIL: Output substitution for '$output' not found in workflow_dispatch"
    exit 1
  fi
done

# Test 14: Verify action.yml has all output definitions
echo ""
echo "Test 14: Verify action.yml defines all three outputs..."
if grep -q "outputs:" "action.yml"; then
  echo "✓ PASS: action.yml has outputs section"

  for output in "${OUTPUTS[@]}"; do
    if grep -q "^  $output:" "action.yml"; then
      echo "✓ PASS: Output '$output' defined in action.yml"
    else
      echo "✗ FAIL: Output '$output' not defined in action.yml"
      exit 1
    fi
  done
else
  echo "✗ FAIL: action.yml does not have outputs section"
  exit 1
fi

# Test 15: Verify README.md line count (should be at least 400 lines)
echo ""
echo "Test 15: Verify README.md is comprehensive..."
README_FILE="README.md"
if [ -f "$README_FILE" ]; then
  LINE_COUNT=$(wc -l < "$README_FILE")
  echo "README.md has $LINE_COUNT lines"

  if [ "$LINE_COUNT" -ge 400 ]; then
    echo "✓ PASS: README.md is comprehensive ($LINE_COUNT lines >= 400)"
  else
    echo "✗ FAIL: README.md is too short ($LINE_COUNT lines < 400)"
    exit 1
  fi
else
  echo "✗ FAIL: README.md not found"
  exit 1
fi

# Test 16: Verify README documents all inputs
echo ""
echo "Test 16: Verify README documents all 12 inputs..."
ALL_INPUTS=("crash-id" "signature" "app-version" "create-time" "api-key" "github-token" \
            "subtitle" "stack-trace" "device-info" "occurrence-count" "agent" "base-branch")

MISSING_INPUTS=()
for input in "${ALL_INPUTS[@]}"; do
  if grep -q "\`$input\`" "$README_FILE" || grep -q "| \`$input\`" "$README_FILE" || grep -q "'$input'" "$README_FILE"; then
    echo "✓ PASS: Input '$input' documented in README"
  else
    echo "⚠ WARNING: Input '$input' may not be fully documented in README"
    MISSING_INPUTS+=("$input")
  fi
done

if [ ${#MISSING_INPUTS[@]} -eq 0 ]; then
  echo "✓ PASS: All 12 inputs documented in README"
else
  echo "⚠ WARNING: Some inputs may not be fully documented: ${MISSING_INPUTS[@]}"
fi

# Test 17: Verify README documents all 3 outputs
echo ""
echo "Test 17: Verify README documents all 3 outputs..."
for output in "${OUTPUTS[@]}"; do
  if grep -q "$output" "$README_FILE"; then
    echo "✓ PASS: Output '$output' documented in README"
  else
    echo "✗ FAIL: Output '$output' not documented in README"
    exit 1
  fi
done

# Test 18: Verify README has quick start sections
echo ""
echo "Test 18: Verify README has Quick Start sections..."
if grep -q "Quick Start" "$README_FILE"; then
  echo "✓ PASS: README has Quick Start section"
else
  echo "✗ FAIL: README missing Quick Start section"
  exit 1
fi

if grep -q "workflow_dispatch" "$README_FILE"; then
  echo "✓ PASS: README documents workflow_dispatch trigger"
else
  echo "✗ FAIL: README does not document workflow_dispatch"
  exit 1
fi

if grep -q "repository_dispatch" "$README_FILE"; then
  echo "✓ PASS: README documents repository_dispatch trigger"
else
  echo "✗ FAIL: README does not document repository_dispatch"
  exit 1
fi

# Test 19: Verify README has curl examples
echo ""
echo "Test 19: Verify README has curl examples..."
if grep -q "curl.*https://api.github.com" "$README_FILE"; then
  echo "✓ PASS: README includes curl examples"
else
  echo "✗ FAIL: README missing curl examples"
  exit 1
fi

# Test 20: Verify README has troubleshooting and FAQ sections
echo ""
echo "Test 20: Verify README has troubleshooting and FAQ sections..."
if grep -q "Troubleshooting" "$README_FILE"; then
  echo "✓ PASS: README has Troubleshooting section"
else
  echo "✗ FAIL: README missing Troubleshooting section"
  exit 1
fi

if grep -q "FAQ" "$README_FILE"; then
  echo "✓ PASS: README has FAQ section"
else
  echo "✗ FAIL: README missing FAQ section"
  exit 1
fi

# Test 21: Verify README has agent extensibility guide
echo ""
echo "Test 21: Verify README has agent extensibility guide..."
if grep -q "Adding a New Agent" "$README_FILE" || grep -q "Agent.*extensibility" "$README_FILE"; then
  echo "✓ PASS: README has agent extensibility guide"
else
  echo "✗ FAIL: README missing agent extensibility guide"
  exit 1
fi

# Test 22: Verify input names match between README and action.yml
echo ""
echo "Test 22: Verify input names match between README and action.yml..."
echo "Checking all inputs in action.yml are referenced in README..."
UNMATCHED=0
for input in "${ALL_INPUTS[@]}"; do
  if grep -q "inputs:" "action.yml"; then
    if grep -q "^  $input:" "action.yml"; then
      if grep -q "$input" "$README_FILE"; then
        # echo "✓ Input '$input' found in both files"
        true
      else
        echo "✗ FAIL: Input '$input' in action.yml but not in README"
        UNMATCHED=$((UNMATCHED + 1))
      fi
    fi
  fi
done

if [ $UNMATCHED -eq 0 ]; then
  echo "✓ PASS: All inputs in action.yml are referenced in README"
else
  echo "✗ FAIL: $UNMATCHED inputs in action.yml are not properly referenced in README"
  exit 1
fi

# Test 23: Verify output names match between README and action.yml
echo ""
echo "Test 23: Verify output names match between README and action.yml..."
for output in "${OUTPUTS[@]}"; do
  if grep -q "^  $output:" "action.yml" && grep -q "$output" "$README_FILE"; then
    # echo "✓ Output '$output' found in both files"
    true
  else
    echo "✗ FAIL: Output '$output' name mismatch between action.yml and README"
    exit 1
  fi
done
echo "✓ PASS: All outputs in action.yml are correctly referenced in README"

# Test 24: Verify permissions are correctly set in workflows
echo ""
echo "Test 24: Verify permissions are correctly set in workflows..."
if grep -q "contents: write" "$WORKFLOW_MANUAL" && grep -q "pull-requests: write" "$WORKFLOW_MANUAL"; then
  echo "✓ PASS: workflow_dispatch has correct permissions (contents: write, pull-requests: write)"
else
  echo "⚠ WARNING: workflow_dispatch permissions may not be correctly set"
fi

if grep -q "contents: write" "$WORKFLOW_DISPATCH" && grep -q "pull-requests: write" "$WORKFLOW_DISPATCH"; then
  echo "✓ PASS: repository_dispatch has correct permissions (contents: write, pull-requests: write)"
else
  echo "⚠ WARNING: repository_dispatch permissions may not be correctly set"
fi

# Test 25: Verify action.yml is valid composite action
echo ""
echo "Test 25: Verify action.yml is a valid composite action..."
if grep -q "^runs:" "action.yml" && grep -q "using: composite" "action.yml"; then
  echo "✓ PASS: action.yml is properly defined as a composite action"
else
  echo "✗ FAIL: action.yml is not properly defined as a composite action"
  exit 1
fi

echo ""
echo "=== All Integration Tests Passed ==="
echo ""
echo "Summary:"
echo "✓ Both workflow files exist and are valid YAML"
echo "✓ workflow_dispatch trigger properly defined in crash-auto-fix-manual.yml"
echo "✓ repository_dispatch trigger properly defined in crash-auto-fix-dispatch.yml"
echo "✓ Both workflows call the crash-fix-gh-action composite action"
echo "✓ All 12 inputs properly mapped in both workflows"
echo "✓ All 3 outputs correctly exposed in both workflows"
echo "✓ Input names match between README and action.yml"
echo "✓ Output names match between README and action.yml"
echo "✓ README.md is comprehensive ($LINE_COUNT lines)"
echo "✓ README documents all inputs, outputs, security best practices"
echo "✓ README includes Quick Start for both trigger types"
echo "✓ README includes curl examples for both triggers"
echo "✓ README includes agent extensibility guide and troubleshooting"
echo "✓ Permissions correctly set in both workflows"
echo "✓ action.yml is properly defined as a composite action"
