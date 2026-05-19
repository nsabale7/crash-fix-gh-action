#!/bin/bash
set -e

PROMPT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$PROMPT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <prompt-file> <output-file>"
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
