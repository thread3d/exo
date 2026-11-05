set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "=== available targets matching cli ==="
"$CMAKE" --build build-ocl --target help 2>/dev/null | grep -i cli | head -5
say "=== full build -j12 ==="
"$CMAKE" --build build-ocl -j12 2>&1 | tail -6
say "[build exit=${PIPESTATUS[0]}]"
ls -1 build-ocl/bin 2>/dev/null | grep -E "^llama-(cli|bench)$"
say "=== linked against OpenCL framework? ==="
otool -L build-ocl/bin/llama-cli 2>/dev/null | grep -i -E "opencl" | head -3
say "=== RUN on the RX 580 (-ngl 99) ==="
./build-ocl/bin/llama-cli -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -n 8 --temp 0 \
  -p 'hi' -ngl 99 --no-display-prompt < /dev/null > ~/ocl-run.out 2> ~/ocl-run.err
say "[run exit=$?]"
say "--- ggml_opencl / device selection messages ---"
grep -i -E "ggml_opencl|ggml_vulkan|CL_|adreno|unsupported GPU|OpenCL 2.0|FP16|loaded backend|available devices|layer.*offload" ~/ocl-run.err | head -30
say "DONE-OCL2"
