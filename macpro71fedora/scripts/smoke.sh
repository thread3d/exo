#!/usr/bin/env bash
# Place a model on the node and ask it one question, so a bring-up can be checked end to end.
#   scripts/smoke.sh [model_id] [max_tokens]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./env.sh
. "$SCRIPT_DIR/env.sh"

MODEL="${1:-mlx-community/Qwen3-0.6B-4bit}"
MAX_TOKENS="${2:-16}"
API="${EXO_API:-http://localhost:52415}"

echo "placing $MODEL ..."
curl -sS -m 60 -X POST "$API/place_instance" \
  -H 'Content-Type: application/json' \
  -d "{\"model_id\":\"$MODEL\"}" > /dev/null || exit 1

echo "waiting for the runner to be ready (load + warmup; minutes on this CPU) ..."
for _ in $(seq 1 120); do
  if grep -q "runner ready" "$LOG_DIR/exo.log" 2>/dev/null; then
    echo "runner ready"
    break
  fi
  sleep 10
done

echo "asking the model ..."
start=$(date +%s)
reply=$(curl -sS -m 900 -X POST "$API/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",
       \"messages\":[{\"role\":\"user\",\"content\":\"Say hello in five words.\"}],
       \"max_tokens\":$MAX_TOKENS}")
echo "$reply"
echo "took $(( $(date +%s) - start ))s"
