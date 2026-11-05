set -u
export PATH=/usr/local/bin:$PATH
cd ~/projects/Exo/exo || exit 1
echo "=== AGENTS.md (build/dev commands) ==="
grep -n -i -e "uv sync" -e "build" -e "cargo" -e "dashboard" AGENTS.md | head -30
echo
echo "=== where is mlx imported ==="
grep -rn "^import mlx\|^from mlx\|^    import mlx\|^ *from mlx" src/exo --include=*.py | head -15
echo
echo "=== extras: mlx-none usage in code/docs ==="
grep -rn "mlx-none" --include=*.py --include=*.md --include=*.toml --include=*.yml -r . 2>/dev/null | grep -v node_modules | head -10
echo
echo "=== rust workspace members now ==="
ls rust
echo "=== git status ==="
git status --short | head
