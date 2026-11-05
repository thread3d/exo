set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama.cpp" || exit 1
say "cmake: $($CMAKE --version | head -1) | HEAD $(git log -1 --format='%h %ad' --date=short)"
say "=== configure (CPU only: Metal off, native march => SSE4.2 on Westmere) ==="
"$CMAKE" -B build -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DLLAMA_CURL=OFF \
        -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=ON -DGGML_NATIVE=ON 2>&1 | tail -18
say "[configure exit=${PIPESTATUS[0]}]"
say "=== build -j12 ==="
"$CMAKE" --build build -j12 2>&1 | tail -20
say "[build exit=${PIPESTATUS[0]}]"
say "=== binaries ==="
ls -1 build/bin 2>/dev/null | head -20
say "=== llama-cli version ==="
./build/bin/llama-cli --version 2>&1 | head -3
say "=== does ggml report any SIMD beyond SSE? ==="
./build/bin/llama-cli --help >/dev/null 2>&1 && say "cli ok"
say "DONE-LLAMACPP-BUILD2"
