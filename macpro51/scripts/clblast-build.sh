set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
SHIM="$HOME/projects/llama.cpp/ocl-shim"
say "=== build CLBlast ==="
cd "$HOME/projects/CLBlast" || exit 1
"$CMAKE" -B build -DCMAKE_BUILD_TYPE=Release -DSAMPLES=OFF -DTESTS=OFF -DCLTUNE=OFF \
  -DCMAKE_CXX_FLAGS="-I\"$SHIM\"" -DCMAKE_C_FLAGS="-I\"$SHIM\"" -DCMAKE_INSTALL_PREFIX="$HOME/projects/CLBlast/dist" \
  2>&1 | grep -E -i "opencl|error|Configuring done|Generating done|Could NOT" | tail -10
say "[CLBlast configure exit=${PIPESTATUS[0]}]"
"$CMAKE" --build build -j12 > ~/clblast-compile.log 2>&1
say "[CLBlast build exit=$?]"
grep -E "error:" ~/clblast-compile.log | head -8
ls -lh build/libclblast* 2>/dev/null | head -3
say "=== install to dist ==="
"$CMAKE" --install build > ~/clblast-install.log 2>&1; say "[install exit=$?]"
find "$HOME/projects/CLBlast/dist" -name "*.dylib" -o -name "clblast.h" -o -name "CLBlastConfig.cmake" 2>/dev/null | head -8
say "DONE-CLBLAST-BUILD"
