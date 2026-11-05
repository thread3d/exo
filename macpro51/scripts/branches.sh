set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
echo "=== newest 12 upstream branches: tip date + subject ==="
for b in $(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin | grep -v '/HEAD$' | head -12); do
  printf '%-46s %s  %s\n' "$b" "$(git log -1 --format='%ad' --date=short "$b")" "$(git log -1 --format='%s' "$b" | cut -c1-70)"
done
echo
echo "=== the branches that carry a vllm engine (Linux/CUDA only) ==="
for b in origin/andrei/dgx-mac-usb-fix origin/leo/dgx-spark-integrations origin/leo/prefill-decode-really origin/leo/use-sm121-branch origin/merge-attempt origin/testing origin/leo/gguf-maybe; do
  printf '%-40s %s  %s\n' "$b" "$(git log -1 --format='%ad' --date=short "$b" 2>/dev/null)" "$(git log -1 --format='%s' "$b" 2>/dev/null | cut -c1-60)"
done
echo
echo "=== does any branch add a CPU/gguf-capable engine (not vllm)? ==="
git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v '/HEAD$' | while read -r b; do
  git ls-tree --name-only "$b":src/exo/worker/engines 2>/dev/null | grep -qE '^(cpu|gguf|llama|torch|ggml)' && echo "FOUND in $b"
done | head
echo "[scan done]"
