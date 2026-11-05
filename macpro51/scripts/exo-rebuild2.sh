set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== dep/crate delta 55eebeed..HEAD ==="
git diff --stat 55eebeed..HEAD -- pyproject.toml uv.lock rust Cargo.toml Cargo.lock dashboard/package.json 2>/dev/null | tail -10
say "=== uv sync --extra mlx-none --no-dev ==="
uv sync --extra mlx-none --no-dev 2>&1 | tail -12
say "[uv sync exit=${PIPESTATUS[0]}]"
say "=== dashboard rebuild ==="
cd dashboard || exit 1
npm install 2>&1 | tail -4
npm run build 2>&1 | tail -6
say "[npm run build exit=${PIPESTATUS[0]}]"
cd ..
say "=== verify ==="
.venv/bin/exo --version
say "DONE-REBUILD"
