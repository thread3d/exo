set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
echo "=== before ==="; git log -1 --format="%h %ad %s" --date=short; git status --short --branch | head -3
echo "=== pull --ff-only ==="; git pull --ff-only 2>&1 | tail -12; echo "[pull exit=$?]"
echo "=== after ==="; git log -1 --format="%h %ad %s" --date=short; git status --short --branch | head -3
echo "=== did deps or the rust crate change? ==="
git diff --stat 55eebeed..HEAD -- pyproject.toml uv.lock rust/ src/exo 2>/dev/null | tail -15
echo "=== version ==="; grep -m1 '^version' pyproject.toml
