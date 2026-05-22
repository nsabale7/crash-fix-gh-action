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
# Supports: Java, Kotlin, Swift, JavaScript, TypeScript, Python, Go, Ruby, PHP, C/C++, C#,
#           XML, JSON, YAML, Bash, Gradle, Groovy, SQL, CSS/SCSS, TSX/JSX, TOML, Markdown
awk '
/^```[a-zA-Z0-9._\/\-]+\.(java|kt|swift|js|ts|tsx|jsx|py|go|rb|php|cpp|c|h|cs|xml|json|yaml|yml|sh|bash|gradle|groovy|proto|sql|css|scss|toml|md)$/ {
    # Extract filename from the code block marker
    match($0, /```([a-zA-Z0-9._\/\-]+\.(java|kt|swift|js|ts|tsx|jsx|py|go|rb|php|cpp|c|h|cs|xml|json|yaml|yml|sh|bash|gradle|groovy|proto|sql|css|scss|toml|md))/, arr)
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

    # Write the code to the file (use printf %s to avoid interpreting escape sequences)
    printf '%s' "$code" > "$filepath"
    CHANGES_APPLIED=$((CHANGES_APPLIED + 1))
    echo "  ✓ Applied"
  fi
done < "$TEMP_DIR/changes.txt"

if [ $CHANGES_APPLIED -eq 0 ]; then
  echo "No structured code changes found in agent output"
  echo ""
  echo "Checking for implicit changes (file modifications detected by git diff)..."

  # Try to detect git changes, but don't silently succeed if parsing failed
  if git diff --quiet; then
    echo ""
    echo "⚠ ERROR: No code changes detected in agent output"
    echo ""
    echo "Claude must output code in markdown code blocks with file paths:"
    echo ""
    echo '```filepath.ext'
    echo 'code here'
    echo '```'
    echo ""
    echo "Agent output was:"
    echo "---"
    cat "$AGENT_OUTPUT" >&2
    echo "---"
    exit 1
  else
    # Git found changes, likely from agent modifying files directly
    echo "⚠ Note: No structured code blocks found, but git detected file changes"
    echo "    Proceeding with commit of git-detected changes"
    exit 0
  fi
else
  echo ""
  echo "✓ Applied $CHANGES_APPLIED code change(s) from agent output"
  exit 0
fi
