#!/usr/bin/env bash
# Start LiteLLM proxy to bridge Claude Code → Ollama local models
# This enables Claude Code to route subagent work to local Qwen models
#
# Prerequisites:
#   pip install litellm[proxy]
#   Ollama running on localhost:11434 with models pulled
#
# Usage:
#   ./scripts/start-litellm.sh          # foreground
#   ./scripts/start-litellm.sh --bg     # background (logs to .claude-logs/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG="$PROJECT_ROOT/litellm-config.yaml"
PORT=4000
LOG_DIR="$PROJECT_ROOT/.claude-logs"

# Verify prerequisites
if ! command -v litellm &>/dev/null; then
  echo "ERROR: litellm not found. Install with: pip install litellm[proxy]"
  exit 1
fi

if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
  echo "WARNING: Ollama does not appear to be running on localhost:11434"
  echo "Start Ollama first, then re-run this script."
  exit 1
fi

# Check required models are pulled
echo "Checking Ollama models..."
REQUIRED_MODELS=("qwen3.5:27b" "qwen2.5-coder:32b" "qwen3.5:35b-a3b")
MISSING=()
for model in "${REQUIRED_MODELS[@]}"; do
  if ! curl -s http://localhost:11434/api/tags | grep -q "$model"; then
    MISSING+=("$model")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Missing models. Pull them with:"
  for model in "${MISSING[@]}"; do
    echo "  ollama pull $model"
  done
  echo ""
  echo "Continuing anyway (LiteLLM will error on requests to missing models)..."
fi

if [ "${1:-}" = "--bg" ]; then
  mkdir -p "$LOG_DIR"
  echo "Starting LiteLLM proxy in background on port $PORT..."
  nohup litellm --config "$CONFIG" --port "$PORT" \
    > "$LOG_DIR/litellm.log" 2>&1 &
  echo $! > "$LOG_DIR/litellm.pid"
  echo "PID: $(cat "$LOG_DIR/litellm.pid")"
  echo "Logs: $LOG_DIR/litellm.log"
  echo ""
  echo "To stop: kill \$(cat $LOG_DIR/litellm.pid)"
else
  echo "Starting LiteLLM proxy on port $PORT..."
  litellm --config "$CONFIG" --port "$PORT"
fi
