# Smoke test: start exo as a coordinator (no worker, no downloads), hit the dashboard, shut it down.
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== starting: exo --no-worker --no-downloads --namespace smoke-test (30s cap) ==="
( .venv/bin/exo --no-worker --no-downloads --namespace smoke-test > ~/exo-smoke.log 2>&1 & echo $! > ~/exo-smoke.pid )
for i in $(seq 1 30); do
  sleep 1
  CODE=$(curl -s -o /tmp/dash.html -w '%{http_code}' --max-time 3 http://127.0.0.1:52415/ 2>/dev/null || true)
  [ "$CODE" = "200" ] && { say "dashboard HTTP $CODE after ${i}s"; break; }
done
say "=== API/state probe ==="
curl -s --max-time 5 -o /tmp/state.json -w 'GET /state -> %{http_code}\n' http://127.0.0.1:52415/state 2>&1
head -c 300 /tmp/state.json 2>/dev/null; echo
say "=== served dashboard is our build? ==="
grep -o -E '<title>[^<]*</title>|<script[^>]*src="[^"]*"' /tmp/dash.html 2>/dev/null | head -5
say "=== startup log (first 25 lines) ==="
head -25 ~/exo-smoke.log 2>&1
say "=== startup log (errors only) ==="
grep -i -E "error|traceback|exception|mlx" ~/exo-smoke.log 2>/dev/null | head -10
say "=== shutting down ==="
PID=$(cat ~/exo-smoke.pid 2>/dev/null || true)
kill "$PID" 2>/dev/null && say "sent TERM to $PID"
sleep 3
kill -0 "$PID" 2>/dev/null && { say "still alive, TERM again"; kill "$PID" 2>/dev/null; sleep 2; }
kill -0 "$PID" 2>/dev/null && say "WARNING still running: $PID" || say "stopped cleanly"
say "DONE-SMOKE"
