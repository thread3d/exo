# Stage B: build the Svelte dashboard (README: required before exo will serve it).
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo/dashboard" || exit 1
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "node $(node --version), npm $(npm --version)"
say "=== npm install ==="
npm install 2>&1 | tail -20
say "[npm install exit=${PIPESTATUS[0]}]"
say "=== npm run build ==="
npm run build 2>&1 | tail -40
say "[npm run build exit=${PIPESTATUS[0]}]"
say "=== build output ==="
ls -la build 2>&1 | head -12
du -sh build 2>/dev/null
say "DONE-STAGE-B"
