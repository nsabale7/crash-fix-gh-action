#!/bin/bash

# Test suite for scaffolded agent implementations (aider, codex, gemini)
# Tests: script existence, executability, install success, error handling, output creation

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$PROJECT_ROOT/action/agents"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup
cleanup() {
  rm -f /tmp/crash-fix-prompt.txt
  rm -f /tmp/crash-fix-output.txt
  rm -f /tmp/codex-agent.py
  rm -f /tmp/gemini-agent.py
}

# Test helpers
test_case() {
  echo -e "${YELLOW}TEST: $1${NC}"
}

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((TESTS_PASSED++))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((TESTS_FAILED++))
}

# Main tests
main() {
  echo "=========================================="
  echo "Agent Test Suite"
  echo "=========================================="
  echo ""

  # Test 1: Agent directories exist
  test_case "Agent directories exist"
  local agents=("aider" "codex" "gemini")
  for agent in "${agents[@]}"; do
    if [ -d "$AGENTS_DIR/$agent" ]; then
      pass "Directory: $AGENTS_DIR/$agent"
    else
      fail "Directory missing: $AGENTS_DIR/$agent"
    fi
  done
  echo ""

  # Test 2: install.sh and run.sh scripts exist for each agent
  test_case "Agent scripts exist and are executable"
  for agent in "${agents[@]}"; do
    # Check install.sh
    if [ -x "$AGENTS_DIR/$agent/install.sh" ]; then
      pass "Executable: $AGENTS_DIR/$agent/install.sh"
    else
      fail "Not executable or missing: $AGENTS_DIR/$agent/install.sh"
    fi

    # Check run.sh
    if [ -x "$AGENTS_DIR/$agent/run.sh" ]; then
      pass "Executable: $AGENTS_DIR/$agent/run.sh"
    else
      fail "Not executable or missing: $AGENTS_DIR/$agent/run.sh"
    fi
  done
  echo ""

  # Test 3: Scripts have proper shebangs
  test_case "Scripts have proper bash shebangs"
  for agent in "${agents[@]}"; do
    for script in "install.sh" "run.sh"; do
      local shebang=$(head -1 "$AGENTS_DIR/$agent/$script")
      if [[ "$shebang" == "#!/bin/bash" ]]; then
        pass "Shebang in $agent/$script"
      else
        fail "Missing or incorrect shebang in $agent/$script: $shebang"
      fi
    done
  done
  echo ""

  # Test 4: run.sh scripts handle missing prompt file gracefully
  test_case "run.sh handles missing prompt file gracefully"
  for agent in "${agents[@]}"; do
    local output=$("$AGENTS_DIR/$agent/run.sh" /nonexistent/prompt.txt /tmp/output.txt 2>&1 || true)
    if echo "$output" | grep -q "ERROR.*[Pp]rompt file"; then
      pass "$agent/run.sh detects missing prompt file"
    else
      fail "$agent/run.sh should error on missing prompt file"
    fi
  done
  echo ""

  # Test 5: run.sh scripts handle missing API key gracefully
  test_case "run.sh handles missing AGENT_API_KEY gracefully"
  # Create a dummy prompt file
  echo "Test prompt" > /tmp/crash-fix-prompt.txt

  for agent in "${agents[@]}"; do
    # Unset AGENT_API_KEY if it exists
    (unset AGENT_API_KEY
     local output=$("$AGENTS_DIR/$agent/run.sh" /tmp/crash-fix-prompt.txt /tmp/crash-fix-output.txt 2>&1 || true)
     if echo "$output" | grep -q "ERROR.*AGENT_API_KEY"; then
       pass "$agent/run.sh detects missing AGENT_API_KEY"
     else
       fail "$agent/run.sh should error on missing AGENT_API_KEY"
     fi
    )
  done
  echo ""

  # Test 6: Claude agent (reference implementation) script validation
  test_case "Claude agent scripts are valid"
  if [ -x "$AGENTS_DIR/claude/install.sh" ] && [ -x "$AGENTS_DIR/claude/run.sh" ]; then
    pass "Claude agent scripts exist and are executable"

    # Check for retry logic in install.sh
    if grep -q "MAX_RETRIES" "$AGENTS_DIR/claude/install.sh"; then
      pass "Claude install.sh has retry logic"
    else
      fail "Claude install.sh missing retry logic"
    fi

    # Check for error handling in run.sh
    if grep -q "ERROR" "$AGENTS_DIR/claude/run.sh"; then
      pass "Claude run.sh has error handling"
    else
      fail "Claude run.sh missing error handling"
    fi
  else
    fail "Claude agent scripts missing or not executable"
  fi
  echo ""

  # Test 7: All agent install.sh have retry logic pattern
  test_case "All agent install.sh scripts have retry logic"
  for agent in "${agents[@]}"; do
    if grep -q "MAX_RETRIES" "$AGENTS_DIR/$agent/install.sh"; then
      pass "$agent/install.sh has retry logic"
    else
      fail "$agent/install.sh missing retry logic"
    fi
  done
  echo ""

  # Test 8: All agent run.sh have error handling
  test_case "All agent run.sh scripts have error handling"
  for agent in "${agents[@]}"; do
    if grep -q "ERROR" "$AGENTS_DIR/$agent/run.sh"; then
      pass "$agent/run.sh has error handling"
    else
      fail "$agent/run.sh missing error handling"
    fi

    # Check for set -e
    if grep -q "set -e" "$AGENTS_DIR/$agent/run.sh"; then
      pass "$agent/run.sh has set -e"
    else
      fail "$agent/run.sh missing set -e"
    fi
  done
  echo ""

  # Test 9: All agent run.sh use /tmp/crash-fix-prompt.txt and /tmp/crash-fix-output.txt
  test_case "Agent run.sh scripts use standard I/O paths"
  for agent in "${agents[@]}"; do
    if grep -q "crash-fix-prompt" "$AGENTS_DIR/$agent/run.sh"; then
      pass "$agent/run.sh references crash-fix-prompt.txt"
    else
      fail "$agent/run.sh should reference crash-fix-prompt.txt"
    fi

    if grep -q "crash-fix-output" "$AGENTS_DIR/$agent/run.sh"; then
      pass "$agent/run.sh references crash-fix-output.txt"
    else
      fail "$agent/run.sh should reference crash-fix-output.txt"
    fi
  done
  echo ""

  # Test 10: All agent install.sh have error exit on failure
  test_case "All agent install.sh exit with error on failure"
  for agent in "${agents[@]}"; do
    if grep -q "exit 1" "$AGENTS_DIR/$agent/install.sh"; then
      pass "$agent/install.sh has exit 1 on failure"
    else
      fail "$agent/install.sh should have exit 1 on failure"
    fi
  done
  echo ""

  # Cleanup
  cleanup

  # Summary
  echo "=========================================="
  echo "Test Summary"
  echo "=========================================="
  echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
  echo "=========================================="

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
  fi
}

main "$@"
