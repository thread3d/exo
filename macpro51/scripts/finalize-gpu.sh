set -u
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== clean up the unusable Vulkan SDK download ==="
rm -f "$HOME/vulkan-sdk.dmg"; rm -rf "$HOME/vulkansdk-unzip"
say "=== discard the failed modern-OpenCL build tree (kept: build/, build-metal/, llama-clblast/) ==="
rm -rf "$HOME/projects/llama.cpp/build-ocl"
say "=== GPU launcher (CLBlast-era build, RX 580) ==="
cat > "$HOME/llm-run-gpu.sh" <<'LAUNCH'
#!/bin/bash
# macpro51: llama.cpp Jun-2024 + CLBlast, running on the Radeon RX 580 via OpenCL.
# Best measured config for 7B models: 4.6 tok/s decode, ~29 tok/s prefill.
# Usage: ~/llm-run-gpu.sh [model.gguf] [port] [ngl]
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
MODEL="${1:-$HOME/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf}"
PORT="${2:-8080}"
NGL="${3:-99}"
exec "$HOME/projects/llama-clblast/build-clblast/bin/server" -m "$MODEL" -t 12 -ngl "$NGL" -c 4096 --port "$PORT" --host 127.0.0.1
LAUNCH
chmod +x "$HOME/llm-run-gpu.sh"
say "=== CPU launcher refresh (modern build, best for small models) ==="
cat > "$HOME/llm-run.sh" <<'LAUNCH'
#!/bin/bash
# macpro51: modern llama.cpp, CPU, 12 threads (no BLAS). Best for small models.
# Usage: ~/llm-run.sh [model.gguf] [port]
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
MODEL="${1:-$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf}"
PORT="${2:-8080}"
exec "$HOME/projects/llama.cpp/build/bin/llama-server" -m "$MODEL" -t 12 -c 8192 --port "$PORT" --host 127.0.0.1
LAUNCH
chmod +x "$HOME/llm-run.sh"
say "=== final inventory ==="
for d in "$HOME/projects/llama.cpp/build" "$HOME/projects/llama.cpp/build-metal" "$HOME/projects/llama-clblast/build-clblast" "$HOME/projects/CLBlast/dist"; do
  printf '%-56s %s\n' "$d" "$(du -sh "$d" 2>/dev/null | cut -f1)"
done
ls -1 "$HOME"/llm-run*.sh
say "=== nothing left running? ==="
pgrep -fl "llama-server|llama-cli|server -m" | grep -v pgrep | head -3 || echo "none"
say "DONE-FINALIZE-GPU"
