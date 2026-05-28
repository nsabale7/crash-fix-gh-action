#!/bin/bash
set -e

AGENT_OUTPUT="${1:-/tmp/agent-output.txt}"

if [ ! -f "$AGENT_OUTPUT" ]; then
  echo "ERROR: Agent output file not found at $AGENT_OUTPUT"
  exit 1
fi

echo "Scanning for code changes in agent output..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# awk writes each code block directly to a temp file, one file per change
# Avoids passing multiline content through delimited streams
awk '
/^```[a-zA-Z0-9._\/\-]+\.(java|kt|swift|js|ts|tsx|jsx|py|go|rb|php|cpp|c|h|cs|xml|json|yaml|yml|sh|bash|gradle|groovy|proto|sql|css|scss|toml|md)$/ {
    match($0, /```(.+)/, arr)
    filename = arr[1]
    if (filename != "") {
        in_block = 1
        tmpfile = TEMP_DIR "/" NR ".code"
        meta = TEMP_DIR "/" NR ".meta"
        print filename > meta
        close(meta)
        next
    }
}

in_block && /^```$/ {
    if (tmpfile != "") {
        close(tmpfile)
        tmpfile = ""
        filename = ""
        in_block = 0
    }
    next
}

in_block {
    print > tmpfile
}
' TEMP_DIR="$TEMP_DIR" "$AGENT_OUTPUT"

CHANGES_APPLIED=0

# Each .meta file contains the target path; matching .code file has the content
for meta_file in "$TEMP_DIR"/*.meta; do
  [ -f "$meta_file" ] || continue

  filepath=$(cat "$meta_file")
  code_file="${meta_file%.meta}.code"

  if [ ! -f "$code_file" ]; then
    echo "  ⚠ Skipping $filepath (empty block)"
    continue
  fi

  echo "Applying change to: $filepath"
  mkdir -p "$(dirname "$filepath")"
  cp "$code_file" "$filepath"
  CHANGES_APPLIED=$((CHANGES_APPLIED + 1))
  echo "  ✓ Applied"
done

if [ $CHANGES_APPLIED -eq 0 ]; then
  echo "No structured code changes found in agent output"

  if git diff --quiet; then
    echo ""
    echo "⚠ ERROR: No code changes detected in agent output"
    echo ""
    echo "Claude must output code in markdown code blocks with file paths:"
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
    echo "⚠ Note: No structured code blocks found, but git detected file changes"
    echo "    Proceeding with commit of git-detected changes"
    exit 0
  fi
else
  echo ""
  echo "✓ Applied $CHANGES_APPLIED code change(s) from agent output"
  exit 0
fi