set -u
cd ~/projects/Exo/exo || exit 1
git -c filter.lfs.required=false fetch --prune origin 2>&1 | tail -20
echo "[fetch exit=$?]"
echo "=== local HEAD ==="
git log -1 --format="%h %ad %s" --date=iso
echo "=== origin/main ==="
git log -1 --format="%h %ad %s" --date=iso origin/main
echo "=== ahead/behind (local...origin/main) ==="
git rev-list --left-right --count main...origin/main
echo "=== incoming commits (count) ==="
git rev-list --count main..origin/main
echo "=== incoming (first 30, oldest last) ==="
git log --oneline main..origin/main | tail -30
