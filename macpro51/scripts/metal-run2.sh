set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
try(){ desc="$1"; shift
  say "=== $desc ==="
  ./build-metal/bin/llama-cli -m "$M" -t 12 -n 24 --temp 0 -p 'Say hello in five words.' --no-display-prompt "$@" \
    < /dev/null > ~/m2.out 2> ~/m2.err
  rc=$?
  if [ $rc -eq 0 ]; then
    say "OK (exit 0)"
    tr '\r' '\n' < ~/m2.out | grep -E "Prompt: .*t/s|hello|Hello" | tail -3
    grep -E "ggml_metal" ~/m2.err | tail -3
  else
    say "FAILED exit=$rc :: $(grep -m1 -E "GGML_ASSERT|error:|GGML_ABORT" ~/m2.err)"
  fi
}
try "mmap off, all layers on GPU (-ngl 99 --no-mmap)" -ngl 99 --no-mmap
try "mmap on, 8 layers only (-ngl 8)" -ngl 8
try "mmap off, 8 layers only (-ngl 8 --no-mmap)" -ngl 8 --no-mmap
try "mmap off, 1 layer (-ngl 1 --no-mmap)" -ngl 1 --no-mmap
say "DONE-METAL-RUN2"
