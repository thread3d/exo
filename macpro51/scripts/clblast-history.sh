set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "=== current clone is shallow; fetching full history to find the CLBlast era ==="
git fetch --unshallow origin 2>&1 | tail -3
say "[unshallow exit=$?]"
say "=== commits touching GGML_CLBLAST (added/removed) ==="
git log --oneline -S "GGML_CLBLAST" --reverse -- CMakeLists.txt ggml/CMakeLists.txt Makefile 2>/dev/null | head -4
say "--- last commits that still mention CLBlast ---"
git log --oneline -S "GGML_CLBLAST" -- CMakeLists.txt ggml/CMakeLists.txt Makefile 2>/dev/null | head -4
say "=== when was GGUF introduced (need GGUF + CLBlast together) ==="
git log --oneline -S "gguf" --reverse -- llama.cpp 2>/dev/null | head -3
say "DONE-CLBLAST-HISTORY"
