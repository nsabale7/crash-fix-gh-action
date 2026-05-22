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

# Map AGENT_API_KEY to GEMINI_API_KEY for Gemini
export GEMINI_API_KEY="$AGENT_API_KEY"

# Create a Python script to invoke Gemini via Google Generative AI
cat > /tmp/gemini-agent.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
import google.generativeai as genai

def main():
    prompt_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/crash-fix-prompt.txt'
    output_file = sys.argv[2] if len(sys.argv) > 2 else '/tmp/crash-fix-output.txt'

    if not os.path.exists(prompt_file):
        print(f"ERROR: Prompt file not found at {prompt_file}", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Read prompt
    with open(prompt_file, 'r') as f:
        prompt = f.read()

    # Configure Gemini API
    genai.configure(api_key=api_key)

    try:
        # Use Gemini 2.0 Flash model
        model = genai.GenerativeModel('gemini-2.0-flash')
        response = model.generate_content(prompt)

        output = response.text

        # Write output
        with open(output_file, 'w') as f:
            f.write(output)

        print("Gemini agent execution completed successfully")
    except Exception as e:
        print(f"ERROR: Gemini API call failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# Run the Python script
python3 /tmp/gemini-agent.py "$PROMPT_FILE" "$OUTPUT_FILE"

# Verify output
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: Agent produced no output"
  exit 1
fi
