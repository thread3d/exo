#!/bin/bash
# bringup.sh - bring the Strata engine up on macpro51 with settings an 8 GB card can survive.
#
#   ./bringup.sh safe     small context, no MTP, generous VRAM reserve  (the first attempt)
#   ./bringup.sh full     the normal defaults: 8 K context, MTP draft layer
#
# The first request on this machine froze it (0 MiB of VRAM free -> the driver paged GPU memory).  So this script
# refuses to send a request into a full card, and checks the host is still alive right after the first token, so a
# freeze is caught in seconds instead of after a ten-minute timeout.
set -u
cd "$(dirname "$0")"
MODE="${1:-safe}"
HOST=192.168.0.118

case "$MODE" in
  safe) CTX=4096;  RESERVE=2560; MTP=off ;;
  full) CTX=8192;  RESERVE=2048; MTP=on  ;;
  *) echo "usage: $0 [safe|full]" >&2; exit 64 ;;
esac

alive() { ping -c1 -W2 "$HOST" >/dev/null 2>&1 && timeout 6 bash -c "echo > /dev/tcp/$HOST/22" 2>/dev/null; }

wait_for_host() {
  for i in $(seq 1 ${WAIT_MINUTES:-90}); do
    if alive; then echo "[host up] $(date +%H:%M:%S)"; return 0; fi
    [ $((i % 5)) -eq 0 ] && echo "  waiting for $HOST ... ($i min)"
    sleep 60
  done
  echo "[host still down after ${WAIT_MINUTES:-90} min]" >&2; return 1
}

alive || wait_for_host || exit 1

echo "[1/6] pushing the pending fixes"
./push.sh strata_control/mac_fit.py metal/setup_mac.py metal/src/gpu/runtime.cpp \
          metal/src/engine/prompt_chain.inc tools/test_setup_mac.py || exit 1

echo "[2/6] the Mac setup tests"
./ssh51.sh 'cd ~/projects/Strata/Strata && .venv/bin/python -m unittest tools.test_setup_mac 2>&1 | tail -3' || exit 1

echo "[3/6] rebuilding strata"
./ssh51.sh 'cd ~/projects/Strata/Strata && .venv/bin/ninja -C build-metal strata > /tmp/rb.log 2>&1; \
            echo "[ninja exit=$?]"; grep -m5 "error:" /tmp/rb.log' || exit 1

echo "[4/6] rewriting the run config ($MODE: context $CTX, VRAM reserve ${RESERVE} MiB, MTP $MTP)"
./ssh51.sh "cd ~/projects/Strata/Strata && CTX=$CTX RESERVE=$RESERVE MTP=$MTP .venv/bin/python - <<'PY'
import json, os, pathlib
p = pathlib.Path('strata-q2_0.json')
c = json.loads(p.read_text())
args = c['args']

def set_flag(name, value=None):
    global args
    if name in args:
        i = args.index(name)
        if value is None:
            del args[i:i + 2]
        else:
            args[i + 1] = value
    elif value is not None:
        args += [name, value]

set_flag('--expert-cache', 'auto')
set_flag('--vram-reserve-mib', os.environ['RESERVE'])
set_flag('--max-context', os.environ['CTX'])
if os.environ['MTP'] == 'off':
    set_flag('--mtp')            # one token per step: fewer buffers, nothing to verify
env = {**c.get('env', {})}
env.pop('STRATA_METAL_WIRE_BUFFERS', None)      # the mlock wiring stays off: it made the freeze worse
env['STRATA_METAL_PROMPT_GEMM'] = '0'            # MetalPerformancePrimitives is macOS 26: no prompt GEMM here
env['STRATA_METAL_PROMPT'] = 'window'           # prompts run through the decode window instead
c['env'] = env
p.write_text(json.dumps(c, indent=1))
print('args:', ' '.join(args))
print('env :', env)
PY" || exit 1

echo "[5/6] starting the server and gating on free VRAM"
./ssh51.sh 'cd ~/projects/Strata/Strata && pkill -f "serve/server.py"; sleep 2; : > strata-q2_0.log; \
            nohup .venv/bin/python serve/server.py --engine strata --config strata-q2_0.json --port 8080 \
              > /tmp/srv.log 2>&1 & sleep 200; \
            curl -sS -m 10 http://127.0.0.1:8080/health 2>&1 | head -2; echo; tail -3 strata-q2_0.log' || exit 1

headroom=$(./ssh51.sh 'cd ~/projects/Strata/Strata && grep -o "[0-9]* MiB of VRAM free with everything loaded" strata-q2_0.log | tail -1')
echo "  free VRAM reported by the engine: ${headroom:-<not reported>}"
case "$headroom" in
  "0 MiB"*) echo "  REFUSING to send a request: the card has nothing free (that is what froze it)." >&2
            echo "  Try a smaller --expert-cache in the config, then rerun." >&2
            exit 2 ;;
esac

echo "[6/6] the first token, with the host watched"
if ! ./ssh51.sh 'cd ~/projects/Strata/Strata && .venv/bin/python - <<"PY"
import json, urllib.request
body = json.dumps({"model": "auto", "messages": [{"role": "user", "content": "Say hello."}],
                   "max_tokens": 4, "temperature": 0, "stream": False}).encode()
req = urllib.request.Request("http://127.0.0.1:8080/v1/chat/completions", data=body,
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=240) as r:
        d = json.loads(r.read().decode())
    print("OK:", d["choices"][0]["message"]["content"][:80])
    print("timings:", json.dumps(d.get("timings")))
except Exception as e:
    print("REQUEST FAILED:", type(e).__name__, str(e)[:200])
PY'; then
  echo "  the request call itself failed (no reply or a timeout)" >&2
fi

if alive; then
  echo "  host still alive after the first token  [OK]"
else
  echo "  !! the host stopped answering right after the request: it froze again." >&2
  echo "  !! it needs a physical restart; do not retry the same settings." >&2
  exit 3
fi

echo
echo "[ok] up and answering.  Next:  ./ssh51.sh 'cd ~/projects/Strata/Strata && .venv/bin/python /tmp/bench.py 8080'"
