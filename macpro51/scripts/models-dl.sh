set -u
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
D="$HOME/models"; mkdir -p "$D"
dl(){ url="$1"; out="$2"; if [ -s "$D/$out" ]; then say "have $out ($(du -h "$D/$out" | cut -f1))"; return; fi
  say "downloading $out"; curl -sS -L --max-time 1800 -o "$D/$out" "$url" && say "ok $out ($(du -h "$D/$out" | cut -f1))" || say "FAILED $out"; }
dl https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
dl https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf Qwen2.5-1.5B-Instruct-Q4_K_M.gguf
say "=== models dir ==="; ls -lh "$D"
say "=== model file sanity (first bytes must be GGUF magic) ==="
for f in "$D"/*.gguf; do printf '%s: ' "$(basename "$f")"; head -c 4 "$f"; echo; done
say "DONE-MODELS"
