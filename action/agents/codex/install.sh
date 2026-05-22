#!/bin/bash
set -e

# Install OpenAI library for Codex agent with retry logic
MAX_RETRIES=3
RETRY_DELAY=2
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
  echo "Attempt $ATTEMPT of $MAX_RETRIES: Installing OpenAI library..."

  if pip install openai; then
    echo "OpenAI library installed successfully"
    exit 0
  fi

  if [ $ATTEMPT -lt $MAX_RETRIES ]; then
    echo "Install failed, retrying in ${RETRY_DELAY} seconds..."
    sleep $RETRY_DELAY
    RETRY_DELAY=$((RETRY_DELAY * 2))
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

echo "Failed to install OpenAI library after $MAX_RETRIES attempts"
exit 1
