#!/bin/bash
set -e

PROMPT_FILE="${1:-/tmp/crash-fix-prompt.txt}"
OUTPUT_FILE="${2:-/tmp/crash-fix-output.txt}"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Prompt file not found at $PROMPT_FILE"
  exit 1
fi

if [ -z "$AGENT_API_KEY" ]; then
  echo "ERROR: AGENT_API_KEY environment variable not set"
  exit 1
fi

# Map AGENT_API_KEY to OPENAI_API_KEY for Aider
export OPENAI_API_KEY="$AGENT_API_KEY"

# Run Aider in non-interactive mode
# --no-auto-commits: do not auto-commit changes
# --no-git: do not use git (since we're in a non-git context or prefer to handle commits externally)
aider --no-auto-commits --no-git < "$PROMPT_FILE" > "$OUTPUT_FILE" 2>&1 || true

# Check if output was generated
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: Agent produced no output"
  exit 1
fi

echo "Aider agent execution completed successfully"
