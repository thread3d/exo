set -u
export PATH=/usr/local/bin:$PATH
cd ~/projects/Exo/exo || exit 1
echo "=== git-lfs on PATH now: $(command -v git-lfs) ($(git-lfs version)) ==="
echo "=== status before pull ==="
git status --short --branch 2>&1 | head -15
echo "[status exit=$?]"
echo "=== HEAD before ==="
git log -1 --format="%h %ad %s" --date=iso
echo "=== pull --ff-only ==="
git pull --ff-only 2>&1 | tail -25
echo "[pull exit=$?]"
echo "=== HEAD after ==="
git log -1 --format="%h %ad %s" --date=iso
echo "=== status after ==="
git status --short --branch 2>&1 | head -15
echo "=== version ==="
grep -m1 '^version' pyproject.toml 2>/dev/null
