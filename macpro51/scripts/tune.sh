set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
cd "$HOME/projects/llama.cpp" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== build variant: BLAS off (Accelerate not used) ==="
"$CMAKE" -B build-noblas -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF \
        -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=OFF -DGGML_NATIVE=ON 2>&1 | tail -3
"$CMAKE" --build build-noblas -j12 --target llama-bench 2>&1 | tail -3
say "[noblas build exit=$?]"
say "=== bench: 1.5B, no-BLAS build, t=12 ==="
./build-noblas/bin/llama-bench -m "$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf" -t 12 -p 128 -n 64 -r 3 2>&1 | grep -E "qwen2|build" | head -4
say "=== bench: 0.5B, no-BLAS build, t=12 ==="
./build-noblas/bin/llama-bench -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -p 128 -n 64 -r 3 2>&1 | grep -E "qwen2|build" | head -4
say "=== thread sweep on 0.5B (BLAS build) ==="
for t in 6 8 10 12 16; do
  R=$(./build/bin/llama-bench -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t $t -p 128 -n 64 -r 2 2>&1 | grep -E "tg64|pp128")
  echo "threads=$t :: $(echo "$R" | tr '\n' ' ')"
done
say "=== Q4_0 model download ==="
D="$HOME/models"
if [ ! -s "$D/Qwen2.5-1.5B-Instruct-Q4_0.gguf" ]; then
  curl -sS -L --max-time 1800 -o "$D/Qwen2.5-1.5B-Instruct-Q4_0.gguf" https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_0.gguf && say "downloaded Q4_0 ($(du -h "$D/Qwen2.5-1.5B-Instruct-Q4_0.gguf" | cut -f1))"
fi
say "=== bench: 1.5B Q4_0 vs Q4_K_M (BLAS build, t=12) ==="
./build/bin/llama-bench -m "$D/Qwen2.5-1.5B-Instruct-Q4_0.gguf" -t 12 -p 128 -n 64 -r 3 2>&1 | grep -E "qwen2" | head -3
say "DONE-TUNE"
