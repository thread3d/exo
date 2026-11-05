set -u
export PATH=/usr/local/bin:$PATH
echo "=== host ==="; hostname; uptime; sw_vers -productVersion
echo "=== repo ==="; cd "$HOME/projects/Exo/exo" && git log -1 --format="%h %ad %s" --date=short && git status --short --branch | head -5
echo "=== toolchain after the interrupted install ==="
for t in uv node npm cargo rustc git-lfs brew; do printf '%-8s %s\n' "$t" "$(command -v $t || echo MISSING)"; done
cargo --version 2>&1; rustc --version 2>&1; uv --version 2>&1; node --version 2>&1; npm --version 2>&1
echo "=== brew state for the three packages ==="
brew list --versions uv node rust 2>&1
echo "=== any brew process still running? ==="
pgrep -fl "brew|Cellar" 2>/dev/null | head -5 || echo none
