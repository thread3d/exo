set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
echo "=== generation: Qwen2.5-0.5B Q4_K_M, -t 12, greedy, 96 tokens ==="
timeout 300 ./build/bin/llama-cli -m "$M" -t 12 -tb 12 -n 96 --temp 0 \
  -p 'Explain in three short sentences why an old Mac Pro with no AVX is still useful for small language models.' \
  --no-display-prompt < /dev/null 2>&1 | grep -v -E '^llama_model_loader:|^load_tensors|^llama_context:' | tail -22
echo "=== [exit=$?] ==="
