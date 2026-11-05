set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama-clblast" || exit 1
M="$HOME/models/mistral-7b-instruct-v0.2.Q4_0.gguf"
say "=== does the OpenCL/CLBlast backend see the RX 580? (-ngl 1 smoke) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 8 -n 4 -ngl 1 -r 1 2>&1 | grep -i -E "opencl|clblast|device|backend|error|qwen|mistral" | head -12
say "=== 7B Q4_0 on CPU (-ngl 0) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "mistral|model" | head -3
say "=== 7B Q4_0 on the RX 580 via CLBlast (-ngl 99) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "mistral|model" | head -3
say "=== 7B Q4_0 partial offload (-ngl 20) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 20 -r 2 2>&1 | grep -E "mistral|model" | head -3
say "DONE-CLBLAST-BENCH"
