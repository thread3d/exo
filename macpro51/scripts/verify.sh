set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
echo "=== git ==="
git log -1 --format="HEAD %h %ad %s" --date=short
git status --short --branch
echo "=== toolchain ==="
printf 'rustc   %s (%s)\n' "$(rustc --version | awk '{print $2}')" "$(command -v rustc)"
printf 'cargo   %s\n' "$(cargo --version | awk '{print $2}')"
printf 'uv      %s\n' "$(uv --version | awk '{print $2}')"
printf 'node    %s (%s)\n' "$(node --version)" "$(command -v node)"
printf 'npm     %s\n' "$(npm --version)"
printf 'python  %s (%s)\n' "$(.venv/bin/python -V 2>&1)" ".venv"
echo "=== build artifacts ==="
printf 'dashboard/build  %s\n' "$(du -sh dashboard/build 2>/dev/null | cut -f1)"
printf 'target/          %s\n' "$(du -sh target 2>/dev/null | cut -f1)"
ls .venv/lib/python3.13/site-packages/exo_rs/*.so 2>/dev/null | head -3
echo "=== console entry points ==="
.venv/bin/exo --version
echo "=== uv run (README form needs --no-dev here) ==="
uv run --no-dev exo --version 2>&1 | tail -3
echo "DONE-VERIFY"
