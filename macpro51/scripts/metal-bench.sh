set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
S="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
L="$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
say "=== is the model actually on the GPU? ==="
grep -E -i "offloaded|layers to GPU|ggml_metal_|buffer_size|Metal0|MTL0" ~/m5.err | head -12
say "=== llama-bench 0.5B: GPU (ngl 99) ==="
./build-metal/bin/llama-bench -m "$S" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "qwen2" | head -3
say "=== llama-bench 1.5B: GPU (ngl 99) ==="
./build-metal/bin/llama-bench -m "$L" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "qwen2" | head -3
say "=== llama-bench 1.5B: hybrid 16 layers GPU + CPU ==="
./build-metal/bin/llama-bench -m "$L" -t 12 -p 128 -n 64 -ngl 16 -r 2 2>&1 | grep -E "qwen2" | head -3
say "DONE-METAL-BENCH"
