set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
echo "=== generation: Qwen2.5-0.5B Q4_K_M, -t 12, greedy, 96 tokens (no timeout binary on macOS; -n bounds it) ==="
./build/bin/llama-cli -m "$M" -t 12 -tb 12 -n 96 --temp 0 \
  -p 'Explain in three short sentences why an old Mac Pro with no AVX is still useful for small language models.' \
  --no-display-prompt < /dev/null > ~/llm-out.txt 2> ~/llm-err.txt
echo "[exit=$?]"
echo "=== generated text ==="
cat ~/llm-out.txt
echo "=== timings ==="
grep -E "llama_perf|tokens per second|prompt eval|eval time|total time" ~/llm-err.txt | tail -12
