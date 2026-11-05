# Build llama.cpp for CPU on macpro51. Xeon X5675 = Westmere: SSE4.2, NO AVX/AVX2/FMA.
set -u
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
say "=== CPU features ==="
FEATS=$(sysctl -n machdep.cpu.features 2>/dev/null); LEAF7=$(sysctl -n machdep.cpu.leaf7_features 2>/dev/null || echo none)
echo "$FEATS" | tr ' ' '\n' | grep -x -E 'SSE4_2|SSE4_1|SSSE3|AVX|FMA' | tr '\n' ' '; echo
cases(){ echo "$FEATS $LEAF7" | grep -q -w "$1" && echo "  $1: yes" || echo "  $1: NO"; }
for f in AVX AVX2 FMA AVX512F; do cases $f; done
say "cores: $(sysctl -n hw.ncpu), mem: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
say "clang: $(clang --version | head -1)"; say "cmake: $(cmake --version | head -1)"

say "=== clone llama.cpp ==="
mkdir -p "$HOME/projects"; cd "$HOME/projects" || exit 1
if [ ! -d llama.cpp/.git ]; then
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git 2>&1 | tail -4
else
  cd llama.cpp && git fetch --depth 1 origin 2>&1 | tail -2 && git reset --hard origin/HEAD 2>&1 | tail -2 && cd ..
fi
cd llama.cpp || exit 1
say "HEAD: $(git log -1 --format='%h %ad %s' --date=short)"
say "=== cmake configure (CPU only, Metal off) ==="
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DLLAMA_CURL=OFF \
      -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=ON 2>&1 | tail -12
say "[cmake configure exit=${PIPESTATUS[0]}]"
say "=== build (-j6) ==="
cmake --build build -j6 2>&1 | tail -25
say "[cmake build exit=${PIPESTATUS[0]}]"
say "=== binaries ==="
ls -lh build/bin 2>/dev/null | head -15
say "DONE-LLAMACPP-BUILD"
