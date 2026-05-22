#!/bin/bash
set -e

echo "=== Testing Apply Changes Script ==="

# Capture the script directory before changing directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && cd .. && pwd)"
APPLY_SCRIPT="$SCRIPT_DIR/action/apply-changes.sh"

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT
cd "$TEST_DIR"

# Initialize git repo
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create a test agent output with code changes
cat > agent-output.txt << 'EOF'
I found the issue! The MainActivity is missing a null check.

Here's the fixed code:

```MainActivity.java
package com.example.app;

public class MainActivity {
    public void processData(String data) {
        if (data == null) {
            return;
        }
        String result = data.toUpperCase();
    }
}
EOF

# Create initial source files
mkdir -p src/main/java/com/example/app
cat > src/main/java/com/example/app/MainActivity.java << 'EOF'
package com.example.app;

public class MainActivity {
    public void processData(String data) {
        String result = data.toUpperCase();  // Missing null check!
    }
}
EOF

git add .
git commit -m "Initial commit"

echo ""
echo "Initial state:"
git diff HEAD

echo ""
echo "Running apply-changes script..."

# Run the apply-changes script using the captured absolute path
if bash "$APPLY_SCRIPT" agent-output.txt; then
    echo "✓ Script completed successfully"

    echo ""
    echo "Changes applied:"
    git diff --stat

    if git diff --quiet; then
        echo "✗ FAIL: No changes were applied"
        exit 1
    else
        echo "✓ PASS: Changes were applied to source file"

        # Verify the content
        if grep -q "if (data == null)" src/main/java/com/example/app/MainActivity.java; then
            echo "✓ PASS: Null check was applied correctly"
        else
            echo "✗ FAIL: Null check not found in file"
            exit 1
        fi
    fi
else
    echo "✗ Script failed"
    exit 1
fi

echo ""
echo "=== All Tests Passed ==="
