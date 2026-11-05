set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
cd "$HOME/projects/llama.cpp" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== rebuild ==="
"$CMAKE" --build build-metal -j12 > ~/metal-build5.log 2>&1
say "[build exit=$?]"
grep -E "error:" ~/metal-build5.log | head -5
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
say "=== generation on the RX 580 (-ngl 99) ==="
./build-metal/bin/llama-cli -m "$M" -t 12 -n 96 --temp 0 -ngl 99 \
  -p 'Name three uses for an old Mac Pro with a Radeon RX 580.' --no-display-prompt \
  < /dev/null > ~/m5.out 2> ~/m5.err
say "[gen exit=$?]"
tail -8 ~/m5.out
grep -E "Prompt: .*t/s|GGML_ASSERT" ~/m5.err | tail -3
say "=== does Metal actually own the model? (backend split) ==="
grep -E -i "load_tensors|offloading|assigned|buffer size|Metal" ~/m5.err | head -10
say "DONE-METAL-RUN5"
