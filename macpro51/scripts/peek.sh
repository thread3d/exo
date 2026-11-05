set -u
cd ~/projects/Exo/exo || exit 1
echo "=== top-level tree of origin/main ==="
git ls-tree --name-only origin/main
echo "=== README (origin/main) first 120 lines ==="
git show origin/main:README.md 2>/dev/null | sed -n '1,120p'
