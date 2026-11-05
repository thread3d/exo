set -u
D="$HOME/models"; mkdir -p "$D"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
F=mistral-7b-instruct-v0.2.Q4_0.gguf
if [ -s "$D/$F" ]; then say "have $F"; else
  say "downloading $F (~4 GB)"
  curl -sS -L --max-time 3600 -o "$D/$F" "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/$F" && say "ok $(du -h "$D/$F" | cut -f1)" || say "FAILED"
fi
head -c 4 "$D/$F" 2>/dev/null; echo " <- magic"
say "DONE-MISTRAL-DL"
