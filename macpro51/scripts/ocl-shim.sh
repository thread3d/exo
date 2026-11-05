set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
SDK=$(xcrun --show-sdk-path)
H="$SDK/System/Library/Frameworks/OpenCL.framework/Headers"
say "SDK: $SDK"
say "framework headers: $(ls "$H" | tr '\n' ' ')"
say "=== does Apple's OpenCL 1.2 export the 2.0-era symbols the backend needs? ==="
LIB=/System/Library/Frameworks/OpenCL.framework/Versions/A/OpenCL
for s in clCreateCommandQueueWithProperties clSVMAlloc clSVMFree clCreateProgramWithIL clCreateImage clEnqueueSVMMemcpy; do
  if nm -gU "$LIB" 2>/dev/null | grep -q " _$s\$"; then echo "  $s: exported"; else echo "  $s: MISSING"; fi
done
say "=== build a CL/ shim so #include <CL/cl.h> resolves ==="
cd "$HOME/projects/llama.cpp" || exit 1
rm -rf ocl-shim; mkdir -p ocl-shim/CL
cp "$H"/*.h ocl-shim/CL/ 2>/dev/null
cp "$H"/*.cl ocl-shim/CL/ 2>/dev/null || true
ls ocl-shim/CL | tr '\n' ' '; echo
say "=== reconfigure with the shim + explicit framework link ==="
"$CMAKE" -B build-ocl -DCMAKE_BUILD_TYPE=Release -DGGML_OPENCL=ON -DGGML_OPENCL_USE_ADRENO_KERNELS=OFF \
  -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=OFF \
  -DGGML_NATIVE=ON -DCMAKE_C_FLAGS="-I$PWD/ocl-shim" -DCMAKE_CXX_FLAGS="-I$PWD/ocl-shim" \
  -DCMAKE_EXE_LINKER_FLAGS="-framework OpenCL" -DCMAKE_SHARED_LINKER_FLAGS="-framework OpenCL" 2>&1 | tail -3
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build ggml-opencl ==="
"$CMAKE" --build build-ocl -j12 > ~/ocl-build2.log 2>&1
say "[build exit=$?]"
grep -E "error:|Undefined symbols|ld: symbol|fatal error" ~/ocl-build2.log | head -15
say "=== did it link? ==="
ls -l build-ocl/bin/libggml-opencl* build-ocl/bin/llama-cli 2>/dev/null | head -5
say "DONE-SHIM"
