set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
SHIM="$PWD/ocl-shim"
say "=== reconfigure with properly quoted shim path ==="
"$CMAKE" -B build-ocl -DCMAKE_BUILD_TYPE=Release -DGGML_OPENCL=ON -DGGML_OPENCL_USE_ADRENO_KERNELS=OFF \
  -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=OFF \
  -DGGML_NATIVE=ON -DCMAKE_C_FLAGS="-I\"$SHIM\"" -DCMAKE_CXX_FLAGS="-I\"$SHIM\"" \
  -DCMAKE_EXE_LINKER_FLAGS="-framework OpenCL" -DCMAKE_SHARED_LINKER_FLAGS="-framework OpenCL" 2>&1 | tail -2
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build ==="
"$CMAKE" --build build-ocl -j12 > ~/ocl-build3.log 2>&1
say "[build exit=$?]"
grep -cE "error:" ~/ocl-build3.log | sed 's/^/compile errors: /'
grep -E "Undefined symbols|^ld: |symbol\(s\) not found|_clSVM|_clCreateCommandQueueWithProperties" ~/ocl-build3.log | head -8
ls -l build-ocl/bin/libggml-opencl* build-ocl/bin/llama-cli 2>/dev/null | awk '{print $5, $9}'
say "=== RUN with -ngl 99 on the RX 580 ==="
if [ -x build-ocl/bin/llama-cli ]; then
  ./build-ocl/bin/llama-cli -m "$HOME/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" -t 12 -n 8 --temp 0 -p 'hi' \
    -ngl 99 --no-display-prompt < /dev/null > ~/ocl-run2.out 2> ~/ocl-run2.err
  say "[run exit=$?]"
  say "--- OpenCL backend verdict from the run ---"
  grep -i -E "ggml_opencl|unsupported GPU|OpenCL 2.0|FP16|Adreno-specific|drop unsupported|loaded OpenCL|devices:" ~/ocl-run2.err | head -20
  say "--- how many layers went to a GPU? ---"
  grep -i -E "offload|ngl|assigned to device|CPU_Mapped|buffer size" ~/ocl-run2.err | head -8
else
  say "llama-cli was not produced"
fi
say "DONE-OCL-FINAL"
