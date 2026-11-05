set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
try(){ desc="$1"; shift
  say "=== $desc ==="
  ./build-metal/bin/llama-cli -m "$M" -t 12 -n 24 --temp 0 -p 'Say hello in five words.' --no-display-prompt "$@" \
    < /dev/null > ~/m3.out 2> ~/m3.err
  rc=$?
  if [ $rc -eq 0 ]; then
    say "OK exit=0"
    tr '\r' '\n' < ~/m3.out | grep -E "Prompt: .*t/s" | tail -2
  else
    say "FAILED exit=$rc :: $(grep -m1 -E "GGML_ASSERT|error:|GGML_ABORT" ~/m3.err)"
  fi
}
try "no-warmup + mmap load + -ngl 99" -ngl 99 --no-warmup -lm mmap
try "no-warmup + mmap+mlock + -ngl 99" -ngl 99 --no-warmup -lm mmap+mlock
try "warmup + mlock load + -ngl 99" -ngl 99 -lm mmap+mlock
say "=== llama-bench on GPU (does it hit the same path?) ==="
./build-metal/bin/llama-bench -m "$M" -t 12 -p 32 -n 16 -ngl 99 -r 1 > ~/mb.log 2>&1
say "[bench exit=$?]"
grep -E "qwen2|GGML_ASSERT|error" ~/mb.log | head -6
say "DONE-METAL-RUN3"
