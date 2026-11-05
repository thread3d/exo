set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
BASE=$(git rev-parse "0e814dfc4^")
say "last CLBlast commit: $BASE  $(git log -1 --format='%ad %s' --date=short "$BASE")"
say "=== CLBlast wiring in that tree ==="
git show "$BASE:CMakeLists.txt" | grep -i -n "clblast" | head -6
git show "$BASE:ggml/src/CMakeLists.txt" 2>/dev/null | grep -i -n "clblast" | head -6 || git show "$BASE:CMakeLists.txt" | grep -i -n "GGML_CLBLAST" | head
say "=== does that tree support Mistral + Q4_K? ==="
git show "$BASE:llama.cpp" | grep -c "LLM_ARCH_MISTRAL" | sed 's/^/mistral refs: /'
git show "$BASE:ggml.c" 2>/dev/null | grep -c "Q4_K" | sed 's/^/Q4_K refs in ggml.c: /'
say "=== create separate worktree so the modern clone is untouched ==="
if [ ! -d "$HOME/projects/llama-clblast" ]; then
  git worktree add "$HOME/projects/llama-clblast" "$BASE" 2>&1 | tail -2
else
  say "worktree already exists"
fi
say "=== model availability check (Mistral-7B Q4_0 era-compatible) ==="
for u in \
  "https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_0.gguf" \
  "https://huggingface.co/unsloth/mistral-7b-instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_0.gguf" \
  "https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/Mistral-7B-Instruct-v0.2-Q4_0.gguf" ; do
  code=$(curl -sI -L --max-time 30 -o /dev/null -w '%{http_code}' "$u")
  size=$(curl -sI -L --max-time 30 "$u" | awk 'tolower($1)=="content-length:"{print $2}' | tail -1)
  echo "$code  ${size:-?}  $u"
done
say "DONE-CLBLAST-PREP"
