#!/bin/bash
set -e

# Build prompt from crash inputs
PROMPT_FILE="/tmp/crash-fix-prompt.txt"

cat > "$PROMPT_FILE" << 'PROMPT_END'
# Crash Fix Task

## Crash Information
PROMPT_END

[ -n "$SIGNATURE" ] && echo "**Signature:** $SIGNATURE" >> "$PROMPT_FILE"
[ -n "$APP_VERSION" ] && echo "**App Version:** $APP_VERSION" >> "$PROMPT_FILE"
[ -n "$DEVICE_INFO" ] && echo "**Device:** $DEVICE_INFO" >> "$PROMPT_FILE"
[ -n "$OCCURRENCE_COUNT" ] && echo "**Occurrences:** $OCCURRENCE_COUNT" >> "$PROMPT_FILE"
[ -n "$CREATE_TIME" ] && echo "**Time:** $CREATE_TIME" >> "$PROMPT_FILE"

cat >> "$PROMPT_FILE" << 'PROMPT_END'

## Stack Trace
PROMPT_END

if [ -n "$STACK_TRACE" ]; then
  echo "$STACK_TRACE" >> "$PROMPT_FILE"
else
  echo "(stack trace not available)" >> "$PROMPT_FILE"
fi

cat >> "$PROMPT_FILE" << 'PROMPT_END'

## Task

Investigate this crash and propose a minimal fix. Your response should:
1. Explain the root cause
2. Identify the file(s) that need changes
3. Provide a patch or code changes
4. Explain why this fix resolves the crash

Scope changes **only** to files implicated by the stack trace. Do not refactor or improve unrelated code.
PROMPT_END

echo "Prompt written to $PROMPT_FILE"
