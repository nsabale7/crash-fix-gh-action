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

# Export for Claude CLI
export ANTHROPIC_API_KEY="$AGENT_API_KEY"

# Run Claude Code CLI non-interactively
claude --print < "$PROMPT_FILE" > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: Agent produced no output"
  exit 1
fi

echo "Agent execution completed successfully"
