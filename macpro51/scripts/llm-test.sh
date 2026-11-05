set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
cd "$HOME/projects/llama.cpp" || exit 1
echo "=== binaries ==="
ls -1 build/bin | head -25
echo "=== llama-cli --version ==="
./build/bin/llama-cli --version 2>&1 | head -3
M="$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf"
echo "=== generation test: Qwen2.5-0.5B Q4_K_M, 12 threads, greedy, 96 tokens ==="
( ./build/bin/llama-cli -m "$M" -t 12 -n 96 -p 'Explain in three short sentences why an old Mac Pro with no AVX is still useful for running small language models.' --temp 0 --no-warmup -no-cnv < /dev/null ) 2>&1 | grep -v -E '^llama_model_loader|^load_|^llm_load' | tail -30
echo "=== exit=$? ==="
