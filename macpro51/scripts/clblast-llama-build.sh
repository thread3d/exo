set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
SHIM="$HOME/projects/llama.cpp/ocl-shim"
cd "$HOME/projects/llama-clblast" || exit 1
say "=== configure llama.cpp (Jun 2024) with CLBlast ==="
"$CMAKE" -B build-clblast -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CLBLAST=ON -DCMAKE_PREFIX_PATH="$HOME/projects/CLBlast/dist" \
  -DLLAMA_METAL=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF \
  -DCMAKE_CXX_FLAGS="-I\"$SHIM\"" -DCMAKE_C_FLAGS="-I\"$SHIM\"" \
  2>&1 | grep -E -i "clblast|opencl|error|Configuring done|Generating done|not found|Could NOT" | tail -12
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build -j12 ==="
"$CMAKE" --build build-clblast -j12 > ~/clblast-llama-compile.log 2>&1
say "[build exit=$?]"
grep -E "error:|Undefined symbols" ~/clblast-llama-compile.log | head -10
say "=== binaries ==="
ls -1 build-clblast/bin 2>/dev/null | head -12
say "=== linked against CLBlast? ==="
for b in build-clblast/bin/llama-cli build-clblast/bin/llama-bench build-clblast/bin/main; do [ -f "$b" ] && { echo "-- $b"; otool -L "$b" | grep -i -E "clblast|opencl" | head -3; }; done
say "DONE-CLBLAST-LLAMA-BUILD"
