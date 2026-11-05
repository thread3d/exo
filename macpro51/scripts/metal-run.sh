set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "=== reconfigure with server ON (app links llama-server-impl) ==="
"$CMAKE" -B build-metal -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=ON \
  -DGGML_NATIVE=ON 2>&1 | tail -2
"$CMAKE" --build build-metal -j12 > ~/metal-build2.log 2>&1
say "[build exit=$?]"
grep -E "error:|ld: library|Undefined symbols" ~/metal-build2.log | head -5
say "=== binaries built ==="; ls -1 build-metal/bin | grep -E "^(llama-cli|llama-bench|llama-server)$"

say "=== CPU baseline for comparison (same binary, -ngl 0) ==="
./build-metal/bin/llama-bench -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "qwen2|build" | head -3

say "=== GPU: Metal, all layers on the RX 580 (-ngl 99) ==="
./build-metal/bin/llama-bench -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "qwen2|Metal|ggml_metal|error|build" | head -12
say "[bench exit=$?]"

say "=== real generation on GPU: 0.5B, 96 tokens ==="
./build-metal/bin/llama-cli -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -n 96 --temp 0 -ngl 99 \
  -p 'Name three uses for an old Mac Pro with a Radeon RX 580.' --no-display-prompt \
  < /dev/null > ~/metal-gen.out 2> ~/metal-gen.err
say "[gen exit=$?]"
tail -3 ~/metal-gen.out
grep -E "Prompt: .*t/s|ggml_metal|MTL|Metal" ~/metal-gen.err | tail -8
say "DONE-METAL-RUN"
