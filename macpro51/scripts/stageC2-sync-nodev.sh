# Stage C2: same sync, minus the dev group (basedpyright -> nodejs-wheel-binaries cannot build on Big Sur).
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== uv sync --extra mlx-none --no-dev ==="
uv sync --extra mlx-none --no-dev 2>&1 | tail -40
RC=${PIPESTATUS[0]}
say "[uv sync --no-dev exit=$RC]"
say "=== venv sanity ==="
.venv/bin/python -V 2>&1
.venv/bin/python -c 'import exo_rs; print("exo_rs import OK:", exo_rs.__file__)' 2>&1 | tail -3
say "=== console script ==="
ls -l .venv/bin/exo 2>&1
.venv/bin/exo --version 2>&1 | tail -5
say "DONE-STAGE-C2"
