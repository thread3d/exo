set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/Exo/exo" || exit 1
echo "=== engine dirs on main ==="
git ls-tree --name-only origin/main:src/exo/worker/engines
echo "=== scanning all remote branches for non-mlx engine dirs ==="
git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v '/HEAD$' > /tmp/br.txt
echo "branches: $(wc -l < /tmp/br.txt)"
while read -r b; do
  extras=$(git ls-tree --name-only "$b":src/exo/worker/engines 2>/dev/null | grep -v -x -e '__init__.py' -e 'base.py' -e 'mlx' -e 'image' | tr '\n' ' ')
  [ -n "$extras" ] && echo "$b -> $extras"
done < /tmp/br.txt | head -30
echo "=== any branch mentioning cpu/sse/avx/no-avx engines? ==="
grep -i -E 'cpu|sse|avx|gguf|llama|torch|vllm|candle' /tmp/br.txt | head -20
echo "=== pyproject extras on latest main (any non-mlx backend?) ==="
git show origin/main:pyproject.toml | sed -n '/optional-dependencies/,/^\[tool/p' | head -25
