set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
echo "=== local HEAD ==="; git log -1 --format="%h %ad %s" --date=short
echo "=== fetch ==="; git fetch --prune --tags origin 2>&1 | tail -6
echo "=== behind origin/main ==="; git rev-list --left-right --count HEAD...origin/main
echo "=== new commits on main since our HEAD ==="; git log --oneline HEAD..origin/main | head -20
echo "=== remote branch count ==="; git branch -r | wc -l
echo "=== 25 most recently updated remote branches ==="
git for-each-ref --sort=-committerdate --format='%(committerdate:short) %(refname:short)' refs/remotes/origin | head -25
echo "=== worker engines: is MLX the only backend? ==="
ls src/exo/worker/engines 2>/dev/null
echo "--- engine registry / backend selection ---"
grep -rn -l -i -E "engine|backend" src/exo/worker/*.py 2>/dev/null | head
grep -rn -i -E "class .*Engine|ENGINES *=|backend *=|mlx_none|MLX_NONE" src/exo/worker/engines/__init__.py src/exo/worker/engines/*.py 2>/dev/null | head -20
echo "=== top-level dirs of interest ==="
ls engines 2>/dev/null; ls python 2>/dev/null | head
