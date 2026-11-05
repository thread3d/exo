set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama-clblast" || exit 1
ln -sfn "/Volumes/Sonnet Raid/Users/threaded/models/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf" /tmp/m/qwen.gguf 2>/dev/null

say "=== Mistral-7B generation ON THE RX 580 (CLBlast, -ngl 99, 100 tokens) ==="
./build-clblast/bin/llama-cli -m /tmp/m/mistral.gguf -t 12 -n 100 --temp 0 -ngl 99 \
  -p 'In two sentences: what does a Radeon RX 580 add to an old Mac Pro?' --no-display-prompt \
  < /dev/null > /tmp/g1.out 2> /tmp/g1.err
say "[exit=$?]"
tail -5 /tmp/g1.out
echo "--- offload proof ---"; grep -i -E "offloaded|ggml_opencl: selecting device|llm_load_tensors" /tmp/g1.err | head -6
say "=== can the old build load our modern Qwen2.5-1.5B? (ngl 0 and ngl 99) ==="
for ngl in 0 99; do
  ./build-clblast/bin/llama-bench -m /tmp/m/qwen.gguf -t 12 -p 64 -n 32 -ngl $ngl -r 1 2>&1 | grep -E -i "Q4_K|error|unknown|arch" | head -3 | sed "s/^/  ngl=$ngl: /"
done
say "DONE-CLBLAST-VERIFY"
