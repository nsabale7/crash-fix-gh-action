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

# Map AGENT_API_KEY to OPENAI_API_KEY for Codex
export OPENAI_API_KEY="$AGENT_API_KEY"

# Create a Python script to invoke Codex via OpenAI API
cat > /tmp/codex-agent.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
from openai import OpenAI

def main():
    prompt_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/crash-fix-prompt.txt'
    output_file = sys.argv[2] if len(sys.argv) > 2 else '/tmp/crash-fix-output.txt'

    if not os.path.exists(prompt_file):
        print(f"ERROR: Prompt file not found at {prompt_file}", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("ERROR: OPENAI_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Read prompt
    with open(prompt_file, 'r') as f:
        prompt = f.read()

    # Initialize OpenAI client
    client = OpenAI(api_key=api_key)

    try:
        # Call Codex (via GPT-3.5-turbo or code-davinci-002 if available)
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a code debugging expert. Analyze crash logs and provide fixes."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=2000
        )

        output = response.choices[0].message.content

        # Write output
        with open(output_file, 'w') as f:
            f.write(output)

        print("Codex agent execution completed successfully")
    except Exception as e:
        print(f"ERROR: Codex API call failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# Run the Python script
python3 /tmp/codex-agent.py "$PROMPT_FILE" "$OUTPUT_FILE"

# Verify output
if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: Agent produced no output"
  exit 1
fi
