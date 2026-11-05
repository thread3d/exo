set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
cd "$HOME/projects/llama.cpp" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }

say "=== make the no-BLAS config canonical in build/ ==="
"$CMAKE" -B build -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF \
        -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=ON -DGGML_NATIVE=ON 2>&1 | tail -3
"$CMAKE" --build build -j12 2>&1 | tail -6
say "[rebuild exit=${PIPESTATUS[0]}]"
rm -rf build-noblas

say "=== confirm backend is CPU (no BLAS) ==="
./build/bin/llama-bench -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -p 32 -n 16 -r 1 2>&1 | grep -E "qwen2|backend" | head -3

say "=== steady-state generation: 1.5B, 12 threads, 200 tokens ==="
./build/bin/llama-cli -m "$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf" -t 12 -tb 12 -n 200 --temp 0 \
  -p 'Write a short technical note on why a Mac Pro 5,1 makes a decent CPU-only inference box.' \
  --no-display-prompt < /dev/null > ~/llm-200.txt 2> ~/llm-200.err
say "[generation exit=$?]"
echo "--- tail of generated text ---"; tail -12 ~/llm-200.txt
echo "--- throughput ---"; grep -E "Prompt: |Generation: |tokens per second" ~/llm-200.err | tail -5; tr '\r' '\n' < ~/llm-200.txt | grep -E "Prompt: .*t/s" | tail -2

say "=== launcher script for later use ==="
cat > "$HOME/llm-run.sh" <<'LAUNCH'
#!/bin/bash
# Start llama.cpp's OpenAI-compatible server on macpro51 (CPU, 12 threads).
# Usage: ~/llm-run.sh [model.gguf] [port]
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
MODEL="${1:-$HOME/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf}"
PORT="${2:-8080}"
exec "$HOME/projects/llama.cpp/build/bin/llama-server" -m "$MODEL" -t 12 -c 8192 --port "$PORT" --host 127.0.0.1
LAUNCH
chmod +x "$HOME/llm-run.sh"
say "wrote ~/llm-run.sh"

say "=== server final check via the launcher ==="
( "$HOME/llm-run.sh" > ~/llama-server2.log 2>&1 & echo $! > ~/llama-server2.pid )
for i in $(seq 1 60); do sleep 1; C=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:8080/health || true); [ "$C" = "200" ] && break; done
say "health: $C after ${i}s"
curl -s --max-time 180 http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"Give me one sentence about CPU-only inference on old Xeons."}],"max_tokens":48,"temperature":0}' \
  -o ~/chat2.json -w 'chat HTTP %{http_code}\n'
python3 -c 'import json;d=json.load(open("/Volumes/Sonnet Raid/Users/threaded/chat2.json"));print("reply:",d["choices"][0]["message"]["content"].strip());print("usage:",d.get("usage"))' 2>&1 | head -5
kill "$(cat ~/llama-server2.pid)" 2>/dev/null; sleep 2
pgrep -f llama-server >/dev/null && say "WARNING server still up" || say "server stopped"
say "DONE-FINALIZE"
