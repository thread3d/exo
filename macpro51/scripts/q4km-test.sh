set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
D=/Users/threaded/models
say "=== download Mistral-7B Q4_K_M (same model, different quant) ==="
if [ ! -s "$D/mistral-7b-instruct-v0.2.Q4_K_M.gguf" ]; then
  curl -sS -L --max-time 3600 -o "$D/mistral-7b-instruct-v0.2.Q4_K_M.gguf" \
    "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf" \
    && say "ok $(du -h "$D/mistral-7b-instruct-v0.2.Q4_K_M.gguf" | cut -f1)" || say "download FAILED"
fi
ln -sfn "$D/mistral-7b-instruct-v0.2.Q4_K_M.gguf" /tmp/m/mistral_km.gguf
say "=== MODERN build, 7B Q4_K_M (CPU) — is the regression Q4_0-specific? ==="
~/projects/llama.cpp/build/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== OLD build, 7B Q4_K_M (CPU only, ngl 0) ==="
~/projects/llama-clblast/build-clblast/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== OLD build, 7B Q4_K_M on the RX 580 (ngl 99) ==="
~/projects/llama-clblast/build-clblast/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== real text generation ON THE GPU (old build binary is 'main') ==="
cd "$HOME/projects/llama-clblast" || exit 1
./build-clblast/bin/main -m /tmp/m/mistral.gguf -t 12 -n 96 --temp 0 -ngl 99 \
  -p 'In two sentences: what does a Radeon RX 580 add to an old Mac Pro for AI?' < /dev/null > /tmp/g2.out 2> /tmp/g2.err
say "[gen exit=$?]"
grep -A6 "RX 580 add" /tmp/g2.out | head -10
grep -E "llama_print_timings|eval time|offloaded|selecting device" /tmp/g2.err | head -6
say "DONE-Q4KM"
