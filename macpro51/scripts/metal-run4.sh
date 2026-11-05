set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
cd "$HOME/projects/llama.cpp" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== rebuild with the fallback patch ==="
"$CMAKE" --build build-metal -j12 > ~/metal-build4.log 2>&1
say "[build exit=$?]"
grep -E "error:|warning: implicit" ~/metal-build4.log | head -5
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
say "=== generation on the RX 580 (-ngl 99, 0.5B, 96 tokens) ==="
./build-metal/bin/llama-cli -m "$M" -t 12 -n 96 --temp 0 -ngl 99 \
  -p 'Name three uses for an old Mac Pro with a Radeon RX 580.' --no-display-prompt \
  < /dev/null > ~/m4.out 2> ~/m4.err
say "[gen exit=$?]"
tail -6 ~/m4.out
grep -E "Prompt: .*t/s|GGML_ASSERT|error" ~/m4.err | tail -4
say "DONE-METAL-RUN4"
