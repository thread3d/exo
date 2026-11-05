# Stage C: python deps + the exo_rs rust bindings (pyo3 via cargo).
# --extra mlx-none because MLX is Apple-silicon-only; upstream uses this extra for a master with no MLX.
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
export UV_PYTHON_DOWNLOADS="${UV_PYTHON_DOWNLOADS:-automatic}"
cd "$HOME/projects/Exo/exo" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "cargo $(cargo --version 2>&1) | rustc $(rustc --version 2>&1) | uv $(uv --version 2>&1)"
say "python candidates: $(ls /usr/local/bin/python3.13 2>/dev/null) ($(/usr/local/bin/python3.13 -V 2>&1))"

say "=== uv sync --extra mlx-none ==="
uv sync --extra mlx-none 2>&1 | tail -60
RC=${PIPESTATUS[0]}
say "[uv sync exit=$RC]"

if [ "$RC" -ne 0 ]; then
  say "=== retry pinning the system python3.13, no managed downloads ==="
  UV_PYTHON_DOWNLOADS=never uv sync --extra mlx-none --python /usr/local/bin/python3.13 2>&1 | tail -40
  say "[uv sync retry exit=${PIPESTATUS[0]}]"
fi

say "=== venv sanity ==="
.venv/bin/python -V 2>&1
.venv/bin/python -c 'import exo_rs; print("exo_rs import OK:", getattr(exo_rs,"__file__","?"))' 2>&1 | tail -3
ls .venv/bin | grep -x exo 2>/dev/null || say "no exo console script yet"
say "DONE-STAGE-C"
