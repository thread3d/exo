set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama-clblast" || exit 1
# use the space-free alias for $HOME (/Users/threaded -> /Volumes/Sonnet Raid/Users/threaded)
M=/Users/threaded/models/mistral-7b-instruct-v0.2.Q4_0.gguf
ls -lh "$M" >/dev/null 2>&1 || { say "model not visible at $M"; M="$(readlink -f "$M")"; say "resolved: $M"; }
say "model: $M"
say "=== 7B Q4_0 CPU baseline (-ngl 0) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "mistral 7B" | head -3
say "=== 7B Q4_0 RX 580 via CLBlast (-ngl 99) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "mistral 7B|ggml_opencl: selecting" | head -4
say "=== 7B Q4_0 partial offload (-ngl 20) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 20 -r 2 2>&1 | grep -E "mistral 7B" | head -3
say "DONE-CLBLAST-BENCH2"
