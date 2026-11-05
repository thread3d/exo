# Stage A3: node whose darwin-x64 build actually runs on macOS 11.7 (v26 is built for 13.5).
set -u
export PATH="$HOME/.local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"

# newest LTS per major for 22/20/18 that ships an osx-x64 tarball
CANDS=$(curl -sS --max-time 30 https://nodejs.org/dist/index.json | python3 -c '
import json,sys
d=json.load(sys.stdin)
best={}
for r in d:
    if "osx-x64-tar" not in r["files"]: continue
    v=r["version"].lstrip("v"); major=int(v.split(".")[0])
    if major in (22,20,18) and major not in best: best[major]=v   # index.json is newest-first
for m in (22,20,18):
    if m in best: print(best[m])
')
say "candidates: $(echo $CANDS)"

for V in $CANDS; do
  say "=== trying node v$V ==="
  curl -sS -L --max-time 600 -o /tmp/node.tar.gz "https://nodejs.org/dist/v$V/node-v$V-darwin-x64.tar.gz" || { say "download failed"; continue; }
  rm -rf /tmp/node-v"$V"-darwin-x64
  tar -xzf /tmp/node.tar.gz -C /tmp || { say "untar failed"; continue; }
  BIN=/tmp/node-v"$V"-darwin-x64/bin/node
  if VER=$("$BIN" --version 2>&1); then
    say "node v$V RUNS: $VER"
    rm -rf "$HOME/.local/opt/node"; mv /tmp/node-v"$V"-darwin-x64 "$HOME/.local/opt/node"
    ln -sf "$HOME/.local/opt/node/bin/node" "$HOME/.local/bin/node"
    ln -sf "$HOME/.local/opt/node/bin/npm"  "$HOME/.local/bin/npm"
    ln -sf "$HOME/.local/opt/node/bin/npx"  "$HOME/.local/bin/npx"
    break
  else
    say "node v$V does not run here: $(echo "$VER" | head -2 | tr '\n' ' ')"
  fi
done

hash -r
say "=== summary ==="
node --version 2>&1; npm --version 2>&1
say "DONE-STAGE-A3"
