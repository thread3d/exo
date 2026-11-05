# Stage A2: toolchain via vendor installers (no brew bottles exist for x86_64 macOS).
# rust: rustup (upstream's documented method) | node: official darwin-x64 tarball | uv: astral installer
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"

say "=== 0. network sanity ==="
curl -sS -o /dev/null -w 'sh.rustup.rs %{http_code}\n' --max-time 20 https://sh.rustup.rs || say "rustup host unreachable"
curl -sS -o /dev/null -w 'nodejs.org %{http_code}\n' --max-time 20 https://nodejs.org/dist/index.json || say "nodejs.org unreachable"
curl -sS -o /dev/null -w 'astral.sh %{http_code}\n' --max-time 20 https://astral.sh/uv/install.sh || say "astral unreachable"

say "=== 1. rustup (stable) ==="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh -y --default-toolchain stable --profile minimal 2>&1 | tail -12
say "[rustup exit=$?]"
"$HOME/.cargo/bin/cargo" --version 2>&1; "$HOME/.cargo/bin/rustc" --version 2>&1

say "=== 2. node (official darwin-x64 tarball, LTS) ==="
NODE_VER=$(curl -sS --max-time 30 https://nodejs.org/dist/index.json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["version"] for x in d if x["lts"] and x["files"].count("osx-x64-tar")>0))')
say "picked node $NODE_VER"
curl -sS -L --max-time 600 -o /tmp/node.tar.gz "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-darwin-x64.tar.gz"
tar -xzf /tmp/node.tar.gz -C /tmp
rm -rf "$HOME/.local/opt/node"
mv "/tmp/node-$NODE_VER-darwin-x64" "$HOME/.local/opt/node"
ln -sf "$HOME/.local/opt/node/bin/node" "$HOME/.local/bin/node"
ln -sf "$HOME/.local/opt/node/bin/npm" "$HOME/.local/bin/npm"
ln -sf "$HOME/.local/opt/node/bin/npx" "$HOME/.local/bin/npx"
hash -r; "$HOME/.local/bin/node" --version 2>&1; "$HOME/.local/bin/npm" --version 2>&1

say "=== 3. uv (astral installer) ==="
curl -LsSf --max-time 300 https://astral.sh/uv/install.sh | sh 2>&1 | tail -8
hash -r
uvbin=$(command -v uv || echo "$HOME/.local/bin/uv")
say "uv at $uvbin"
"$uvbin" --version 2>&1 || say "uv FAILED TO RUN on macOS $(sw_vers -productVersion)"

say "=== 4. summary ==="
printf 'cargo  %s\n' "$("$HOME/.cargo/bin/cargo" --version 2>&1)"
printf 'rustc  %s\n' "$("$HOME/.cargo/bin/rustc" --version 2>&1)"
printf 'node   %s\n' "$("$HOME/.local/bin/node" --version 2>&1)"
printf 'npm    %s\n' "$("$HOME/.local/bin/npm" --version 2>&1)"
printf 'uv     %s\n' "$(command -v uv >/dev/null 2>&1 && uv --version 2>&1 || echo UNAVAILABLE)"
say "DONE-STAGE-A2"
