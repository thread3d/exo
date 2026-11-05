set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "=== configure with GGML_OPENCL=ON (Adreno kernels OFF so non-Adreno is even considered) ==="
"$CMAKE" -B build-ocl -DCMAKE_BUILD_TYPE=Release -DGGML_OPENCL=ON -DGGML_OPENCL_USE_ADRENO_KERNELS=OFF \
        -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_SERVER=OFF -DGGML_NATIVE=ON 2>&1 | grep -E -i "opencl|error|not found|Configuring|Generating|Could NOT" | tail -15
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build llama-cli (OpenCL backend compiles the .cl kernels into the binary) ==="
"$CMAKE" --build build-ocl -j12 --target llama-cli 2>&1 | tail -8
say "[build exit=${PIPESTATUS[0]}]"
say "=== linked against OpenCL? ==="
otool -L build-ocl/bin/llama-cli 2>/dev/null | grep -i -E "opencl|ggml" | head -8
say "=== RUN: does it accept the RX 580? (-ngl 99, 0.5B model) ==="
./build-ocl/bin/llama-cli -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -n 8 --temp 0 \
  -p 'hi' -ngl 99 --no-display-prompt < /dev/null > ~/ocl-run.out 2> ~/ocl-run.err
say "[run exit=$?]"
say "--- ggml_opencl messages ---"
grep -i -E "opencl|CL_|device|adreno|unsupported|required|fp16" ~/ocl-run.err | head -25
say "--- did it use the GPU or fall back? ---"
grep -i -E "load_backend|ggml_backend_dev|offload|ngl|offloaded|CPU model buffer" ~/ocl-run.err | head -10
say "DONE-OCL"
