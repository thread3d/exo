set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export DYLD_LIBRARY_PATH="$HOME/projects/CLBlast/dist/lib"
CMAKE=/usr/local/Cellar/cmake/3.31.5/bin/cmake
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
M=/tmp/m/mistral.gguf
say "=== system_info from each build (SIMD flags) ==="
echo "--- modern (Nov 2026) ---"
~/projects/llama.cpp/build/bin/llama-cli -m "$M" -n 1 -p hi --no-display-prompt < /dev/null 2>&1 | grep -i -A2 "system_info\|built with" | head -8
echo "--- old (Jun 2024) ---"
~/projects/llama-clblast/build-clblast/bin/llama-cli -m "$M" -n 1 -p hi --no-display-prompt < /dev/null 2>&1 | grep -i -A2 "system_info\|built with" | head -8

say "=== attribution: build the SAME old commit WITHOUT CLBlast, CPU only ==="
cd "$HOME/projects/llama-clblast" || exit 1
"$CMAKE" -B build-oldcpu -DCMAKE_BUILD_TYPE=Release -DLLAMA_CLBLAST=OFF -DLLAMA_METAL=OFF \
  -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF 2>&1 | tail -2
"$CMAKE" --build build-oldcpu -j12 --target llama-bench > ~/oldcpu-build.log 2>&1
say "[old-cpu-only build exit=$?]"
say "=== 7B Q4_0 on the OLD code, CPU only, no CLBlast anywhere ==="
./build-oldcpu/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "=== and the old build WITH CLBlast at ngl 0, same params (is CLBlast helping at ngl 0?) ==="
./build-clblast/bin/llama-bench -m "$M" -t 12 -p 128 -n 64 -ngl 0 -r 2 2>&1 | grep -E "Q4_0" | head -3
say "DONE-ATTRIBUTION"
