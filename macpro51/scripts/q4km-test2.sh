set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
D="$HOME/models"
F=mistral-7b-instruct-v0.2.Q4_K_M.gguf
if [ ! -s "$D/$F" ]; then
  say "downloading $F"
  curl -sS -L --max-time 3600 -o "$D/$F" "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/$F" && say "ok $(du -h "$D/$F" | cut -f1)" || { say "FAILED"; exit 1; }
fi
ln -sfn "$D/$F" /tmp/m/mistral_km.gguf
say "=== MODERN (Nov 2026) build, 7B Q4_K_M, CPU ==="
~/projects/llama.cpp/build/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== OLD (Jun 2024) build, 7B Q4_K_M, CPU ==="
~/projects/llama-clblast/build-clblast/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== OLD build, 7B Q4_K_M, RX 580 (ngl 99) ==="
~/projects/llama-clblast/build-clblast/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 128 -n 64 -ngl 99 -r 2 2>&1 | grep -E "Q4_K" | head -3
say "=== OLD build, 7B Q4_K_M, RX 580, long prompt (p512, ngl 99) ==="
~/projects/llama-clblast/build-clblast/bin/llama-bench -m /tmp/m/mistral_km.gguf -t 12 -p 512 -n 32 -ngl 99 -r 1 2>&1 | grep -E "Q4_K" | head -3
say "DONE-Q4KM2"
