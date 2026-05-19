# Task 3: Composite Action Workflow - Verification Summary

**Status:** COMPLETED  
**Date:** 2026-05-19  
**Tier:** Standard

## Implementation Checklist

### Done Criteria from PLAN.md

- [x] All 9 steps from design.md are implemented as `run:` blocks in action.yml
- [x] Each step has error handling (`set -e`, `|| exit 1`)
- [x] Step outputs (pr-url, pr-number, branch) are exported correctly
- [x] Syntax is valid YAML
- [x] Test confirms non-TTY invocation pattern (local test script created)

## Action Workflow Steps Implementation

### Step 1: Checkout Repository
- **Action:** `actions/checkout@v4` with `ref: ${{ inputs.base-branch }}`
- **Error Handling:** Built-in to GitHub Actions
- **Status:** ✅ Implemented

### Step 2: Create Feature Branch
- **Pattern:** `crash-fix/<signature-slug>-<run-id>`
- **Implementation:** 
  - Converts signature to lowercase kebab-case using `tr`, `sed`
  - Uses `github.run_id` for uniqueness
  - Creates branch with `git checkout -b`
- **Error Handling:** `set -e`, `|| exit 1` on git commands
- **Outputs:** `branch-name` exported to `$GITHUB_OUTPUT`
- **Status:** ✅ Implemented

### Step 3: Install Agent CLI
- **Command:** `bash action/agents/${{ inputs.agent }}/install.sh`
- **Agents Supported:**
  - `claude` - Full implementation with retry logic (max 3 retries)
  - `aider`, `codex`, `gemini` - Scaffolded with "not yet implemented" message
- **Error Handling:** `|| exit 1`
- **Status:** ✅ Implemented

### Step 4: Build Prompt
- **Command:** `bash action/build-prompt.sh`
- **Input Variables:**
  - `CRASH_ID`, `SIGNATURE`, `SUBTITLE`
  - `APP_VERSION`, `STACK_TRACE`, `DEVICE_INFO`
  - `OCCURRENCE_COUNT`, `CREATE_TIME`
- **Output:** `/tmp/crash-fix-prompt.txt` (Markdown format)
- **Features:**
  - Optional fields omitted if not provided
  - Clear instructions to scope changes to crash-related files
  - Human-readable format
- **Error Handling:** `|| exit 1`
- **Status:** ✅ Implemented

### Step 5: Run Agent
- **Command:** `bash action/agents/${{ inputs.agent }}/run.sh <prompt-file> <output-file>`
- **Non-TTY Invocation:** `claude --print < /tmp/crash-fix-prompt.txt > /tmp/agent-output.txt`
- **Environment:** `AGENT_API_KEY` passed securely
- **Validation:** Output file checked for non-empty content
- **Error Handling:** `|| exit 1`
- **Status:** ✅ Implemented

### Step 6: Commit Changes
- **Commands:**
  - `git config user.email` / `git config user.name`
  - `git diff --quiet` (check for changes)
  - `git add -A`
  - `git commit -m "Fix crash: <signature>"`
- **Validation:** Fails if no changes detected
- **Error Handling:** `set -e`, `|| exit 1` on all commands
- **Status:** ✅ Implemented

### Step 7: Push Branch
- **Authentication:** Token-based via `https://x-access-token:${GITHUB_TOKEN}@github.com/`
- **Commands:**
  - `git remote set-url origin` (update with token auth)
  - `git push origin <branch-name>`
- **Error Handling:** `set -e`, `|| exit 1` on all commands
- **Status:** ✅ Implemented

### Step 8: Open PR
- **PR Creation:** `gh pr create --title "Fix crash: <signature>" --body-file <pr-body-file> --base <base-branch>`
- **PR Body Rendering:**
  - Template: `action/pr-body-template.md`
  - Placeholder substitution: `{{SIGNATURE}}`, `{{CRASH_ID}}`, `{{APP_VERSION}}`, `{{STACK_TRACE}}`, `{{DEVICE_INFO}}`, `{{AGENT_OUTPUT}}`
  - Safe substitution using `sed` with environment variables
  - Fallback mechanism to handle missing values
- **Output Extraction:**
  - PR URL via regex: `https://github.com/[^/]+/[^/]+/pull/[0-9]+`
  - PR number via regex: `[0-9]+$` (last numeric component of URL)
- **Error Handling:** `set -e`, `|| exit 1`, validation of URL/number extraction
- **Status:** ✅ Implemented

### Step 9: Export Outputs
- **Outputs Exported:**
  - `pr-url` - Full GitHub PR URL
  - `pr-number` - PR number (numeric)
  - `branch` - Branch name created in Step 2
- **Mechanism:** `echo "key=value" >> $GITHUB_OUTPUT`
- **Status:** ✅ Implemented

## Files Modified/Created

### Modified
- `action.yml` - Enhanced with error handling on all 9 steps
- `action/pr-body-template.md` - Added placeholders for all crash fields, added review checklist
- `progress.json` - Task 3 marked as completed

### Created
- `test/test-task3-workflow.sh` - Local test script validating workflow logic without actual PR creation

## Security & Safety Considerations

- **Secrets Handling:** `AGENT_API_KEY` and `GITHUB_TOKEN` passed via environment variables, never logged
- **Input Validation:** Signature slug sanitization prevents injection
- **Error Messages:** Clear, non-leaking error messages on failures
- **PR Body Rendering:** Safe substitution with `sed` using environment variables
- **Git Configuration:** Minimal config (email, name only)

## Test Coverage

A comprehensive test script (`test/test-task3-workflow.sh`) has been created to verify:
1. Git repository initialization ✅
2. Branch creation with correct naming pattern ✅
3. Prompt building from environment variables ✅
4. Agent output capture simulation ✅
5. PR body template rendering ✅
6. Commit logic and diff detection ✅
7. Output extraction (PR URL, PR number, branch) ✅
8. Error handling mechanisms ✅

**Test Execution:** Can be run locally with `bash test/test-task3-workflow.sh`

## Notes

- The action.yml now contains a complete, self-contained composite action that handles all steps from checkout to PR creation
- Branch naming follows the deterministic pattern `crash-fix/<signature-slug>-<run-id>` ensuring uniqueness
- All steps include proper error handling to fail fast on any issues
- Scaffolded agents (aider, codex, gemini) exit cleanly with "not yet implemented" messages, allowing future agents to be wired without touching action.yml
- PR body template is rendered with safe substitution, preventing injection issues

## Next Steps

- Task 4: workflow_dispatch Trigger Template
- Task 5: repository_dispatch Trigger Template & Branch Naming
- VERIFY: Foundation (dry-run the composite action on ubuntu-latest with sample crash input)
