set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
M=/tmp/m/mistral.gguf

say "=== MODERN CPU build, 7B Q4_0 (canonical no-BLAS) ==="
cd "$HOME/projects/llama.cpp" || exit 1
./build/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -r 2 2>&1 | grep -E "Q4_0" | head -3
./build/bin/llama-bench -m "$M" -t 12 -p 512 -n 32 -r 1 2>&1 | grep -E "Q4_0" | head -3

say "=== MODERN METAL build, 7B Q4_0 (-ngl 99) ==="
./build-metal/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "Q4_0" | head -3
./build-metal/bin/llama-bench -m "$M" -t 12 -p 512 -n 32 -ngl 99 -r 1 2>&1 | grep -E "Q4_0" | head -3

say "=== CLBLAST build, 7B Q4_0 CPU baseline at p512 (-ngl 0) ==="
cd "$HOME/projects/llama-clblast" || exit 1
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 512 -n 32 -ngl 0 -r 1 2>&1 | grep -E "Q4_0" | head -3
say "DONE-FINAL-MATRIX"
