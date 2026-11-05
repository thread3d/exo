set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama-clblast" || exit 1
M=/tmp/m/mistral.gguf
say "=== 7B Q4_0 CPU (-ngl 0) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "=== 7B Q4_0 ALL layers on RX 580 via CLBlast (-ngl 99) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "=== 7B Q4_0 half offload (-ngl 16) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 16 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "=== 7B Q4_0 GPU, bigger batch prefill (-ngl 99, p512) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 512 -n 32 -ngl 99 -r 1 2>&1 | grep -E "Q4_0" | head -3
say "DONE-CLBLAST-BENCH3"
