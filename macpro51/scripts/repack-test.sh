set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "=== MODERN build, 7B Q4_0, repack ON (default) vs OFF ==="
./build/bin/llama-bench -m /tmp/m/mistral.gguf -t 12 -p 128 -n 64 --repack 1 -r 2 2>&1 | grep -E "Q4_0" | head -3
./build/bin/llama-bench -m /tmp/m/mistral.gguf -t 12 -p 128 -n 64 --repack 0 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "=== MODERN build, 7B Q4_K_M, repack ON vs OFF ==="
./build/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 --repack 1 -r 2 2>&1 | grep -E "Q4_K" | head -3
./build/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 --repack 0 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "DONE-REPACK"
