set -u
export PATH=/usr/local/bin:$PATH
export HOMEBREW_NO_ENV_HINTS=1
echo "=== before ==="
cargo --version; rustc --version
command -v uv node 2>/dev/null || echo "uv/node absent"
echo "=== brew update (formula repo only) ==="
brew update 2>&1 | tail -5
echo "=== brew install uv node ==="
brew install uv node 2>&1 | tail -25
echo "[uv/node install exit=$?]"
echo "=== brew upgrade rust ==="
brew upgrade rust 2>&1 | tail -25
echo "[rust upgrade exit=$?]"
echo "=== after ==="
cargo --version; rustc --version
uv --version 2>&1; node --version 2>&1; npm --version 2>&1
echo "=== paths ==="
command -v uv node npm cargo rustc
