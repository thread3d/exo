set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
TARGET=$(git rev-parse "554c247ca^")
say "target commit: $TARGET  $(git log -1 --format='%ad %s' --date=short "$TARGET")"
say "=== does it have the CLBlast backend? ==="
git ls-tree -r --name-only "$TARGET" | grep -i -E "opencl|clblast" | head -6
git show "$TARGET:ggml/src/ggml-opencl.cpp" 2>/dev/null | grep -c -i clblast | sed 's/^/clblast refs in ggml-opencl.cpp: /'
git show "$TARGET:ggml/CMakeLists.txt" 2>/dev/null | grep -i -n "clblast\|OPENCL" | head -6
say "=== repoint the worktree ==="
git worktree remove --force "$HOME/projects/llama-clblast" 2>/dev/null
git worktree add "$HOME/projects/llama-clblast" "$TARGET" 2>&1 | tail -2
say "=== clone CLBlast ==="
cd "$HOME/projects" || exit 1
if [ ! -d CLBlast/.git ]; then git clone --depth 1 https://github.com/CNugteren/CLBlast.git 2>&1 | tail -2; fi
cd CLBlast && say "CLBlast HEAD: $(git log -1 --format='%h %ad' --date=short)"
say "DONE-CLBLAST-SETUP"
