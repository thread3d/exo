# Stage A: prerequisites for the rewritten exo (uv, node>=18, rust>=1.85). Survives ssh drops via nohup.
set -u
export PATH=/usr/local/bin:$PATH
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_AUTO_UPDATE=1
cd "$HOME/projects/Exo/exo" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }

say "=== current state ==="
for t in uv node npm cargo rustc git-lfs; do printf '%-8s %s\n' "$t" "$(command -v $t || echo MISSING)"; done
cargo --version 2>&1; uv --version 2>&1; node --version 2>&1

say "=== brew install uv node ==="
brew install uv node 2>&1 | tail -20
say "[uv+node exit=${PIPESTATUS[0]}]"

say "=== brew upgrade rust (needs >= 1.85 for edition 2024) ==="
brew upgrade rust 2>&1 | tail -20
say "[rust upgrade exit=${PIPESTATUS[0]}]"
# the rust bottle installs `rust` with cargo/rustc; make sure the newer one wins
hash -r
say "=== resulting versions ==="
cargo --version 2>&1; rustc --version 2>&1; uv --version 2>&1; node --version 2>&1; npm --version 2>&1
say "DONE-STAGE-A"
