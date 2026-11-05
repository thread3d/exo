set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
S=$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
L=$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf
say(){ echo "[$(date '+%H:%M:%S')] $*"; }

say "=== llama-bench: 0.5B Q4_K_M ==="
./build/bin/llama-bench -m "$S" -t 12 -p 128 -n 64 -r 3 2>&1 | tail -8
say "=== llama-bench: 1.5B Q4_K_M ==="
./build/bin/llama-bench -m "$L" -t 12 -p 128 -n 64 -r 3 2>&1 | tail -8
say "=== llama-bench: 1.5B with 24 threads (hyperthreads) for comparison ==="
./build/bin/llama-bench -m "$L" -t 24 -p 128 -n 64 -r 2 2>&1 | tail -8

say "=== llama-server smoke test (1.5B, port 8080, 90s) ==="
./build/bin/llama-server -m "$L" -t 12 -c 4096 --port 8080 --no-webui > ~/llama-server.log 2>&1 &
SPID=$!
for i in $(seq 1 60); do
  sleep 1
  C=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:8080/health 2>/dev/null || true)
  [ "$C" = "200" ] && { say "server healthy after ${i}s"; break; }
done
say "--- OpenAI-compatible chat completion ---"
curl -s --max-time 120 http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"In one sentence: what is a Mac Pro 5,1 good for in 2026?"}],"max_tokens":64,"temperature":0}' \
  -o ~/chat.json -w 'HTTP %{http_code}\n'
python3 - <<'PY'
import json
try:
    d=json.load(open('/Volumes/Sonnet Raid/Users/threaded/chat.json'))
    print("reply:", d["choices"][0]["message"]["content"].strip())
    print("usage:", d.get("usage"))
except Exception as e:
    print("parse failed:", e)
    print(open('/Volumes/Sonnet Raid/Users/threaded/chat.json').read()[:400])
PY
say "=== stopping server ==="
kill $SPID 2>/dev/null; sleep 2
kill -0 $SPID 2>/dev/null && { kill -9 $SPID 2>/dev/null; say "killed -9"; } || say "stopped cleanly"
say "DONE-BENCH-SERVE"
