#!/bin/bash
set -e

# This script parses Claude's output and applies code changes to files
# Claude's output should contain code fixes in markdown code blocks with file paths
# Format: ```filepath.ext
#         code here
#         ```

AGENT_OUTPUT="${1:-/tmp/agent-output.txt}"

if [ ! -f "$AGENT_OUTPUT" ]; then
  echo "ERROR: Agent output file not found at $AGENT_OUTPUT"
  exit 1
fi

echo "Scanning for code changes in agent output..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Use awk to extract code blocks with filenames
# Looks for: ```filename.ext ... ```
awk '
/^```[a-zA-Z0-9._\/\-]+\.(java|kt|swift|js|ts|py|go|rb|php|cpp|c|h|cs|xml|json|yaml|yml|sh|bash)$/ {
    # Extract filename from the code block marker
    match($0, /```([a-zA-Z0-9._\/\-]+\.(java|kt|swift|js|ts|py|go|rb|php|cpp|c|h|cs|xml|json|yaml|yml|sh|bash))/, arr)
    filename = arr[1]
    if (filename != "") {
        in_block = 1
        code = ""
        next
    }
}

in_block && /^```$/ {
    # End of code block - output the change
    if (filename != "") {
        print "CHANGE:" filename ":" code
        filename = ""
        in_block = 0
    }
    next
}

in_block {
    # Accumulate code lines
    if (code == "") {
        code = $0
    } else {
        code = code "\n" $0
    }
}
' "$AGENT_OUTPUT" > "$TEMP_DIR/changes.txt"

CHANGES_APPLIED=0

# Process extracted changes
while IFS=':' read -r marker filepath code; do
  if [ "$marker" = "CHANGE" ] && [ -n "$filepath" ]; then
    echo "Applying change to: $filepath"

    # Create directories if needed
    mkdir -p "$(dirname "$filepath")"

    # Write the code to the file
    printf '%b' "$code" > "$filepath"
    CHANGES_APPLIED=$((CHANGES_APPLIED + 1))
    echo "  ✓ Applied"
  fi
done < "$TEMP_DIR/changes.txt"

if [ $CHANGES_APPLIED -eq 0 ]; then
  echo "No structured code changes found in agent output"
  echo ""
  echo "Checking for implicit changes (file modifications detected by git diff)..."

  if git diff --quiet; then
    echo ""
    echo "⚠ No file changes detected in working directory"
    echo ""
    echo "To apply Claude's suggestions, ensure Claude outputs code in this format:"
    echo ""
    echo '```filepath.ext'
    echo 'code here'
    echo 'more code'
    echo '```'
    echo ""
    exit 1
  else
    echo "✓ Git detected file changes - proceeding with commit"
    exit 0
  fi
else
  echo ""
  echo "✓ Applied $CHANGES_APPLIED code change(s) from agent output"
  exit 0
fi
