set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== Metal toolchain present? (required to compile ggml-metal shaders) ==="
xcrun -f metal 2>&1 | head -2
xcrun -sdk macosx metal --version 2>&1 | head -3
xcode-select -p
say "=== configure Metal build ==="
cd "$HOME/projects/llama.cpp" || exit 1
"$CMAKE" -B build-metal -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=OFF \
  -DGGML_NATIVE=ON 2>&1 | grep -E -i "metal|error|Configuring done|Generating done|Could NOT" | tail -12
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build -j12 ==="
"$CMAKE" --build build-metal -j12 > ~/metal-build.log 2>&1
say "[build exit=$?]"
grep -E "error:|Undefined symbols|fatal error" ~/metal-build.log | head -10
ls -1 build-metal/bin 2>/dev/null | grep -E "^(llama-cli|llama-bench)$"
say "DONE-METAL-BUILD"
