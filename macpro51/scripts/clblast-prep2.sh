set -u
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
say(){ echo "[$(date '+%H:%M:%S')] $*"; }
cd "$HOME/projects/llama-clblast" || exit 1
say "=== tree layout at a95631ee (Jun 2024) ==="
ls
say "=== CLBlast option ==="
grep -rn -i "clblast" CMakeLists.txt ggml/CMakeLists.txt src/CMakeLists.txt 2>/dev/null | head -8
say "=== arch support: qwen2 / llama3? ==="
for a in LLM_ARCH_QWEN2 LLM_ARCH_LLAMA3 LLM_ARCH_MISTRAL LLM_ARCH_LLAMA; do printf '%-18s %s\n' "$a" "$(grep -c "$a" src/llama.cpp 2>/dev/null)"; done
say "=== what GGUF quants does it know? ==="
grep -o "GGML_TYPE_Q[0-9_]*" ggml/include/ggml.h | sort -u | tr '\n' ' '; echo
say "=== HF repo file listing (find an available Q4_0/Q4_K_M) ==="
for r in bartowski/Mistral-7B-Instruct-v0.3-GGUF bartowski/Llama-3.2-3B-Instruct-GGUF bartowski/Llama-3.2-1B-Instruct-GGUF TheBloke/Mistral-7B-Instruct-v0.2-GGUF; do
  echo "--- $r"
  curl -s --max-time 40 "https://huggingface.co/api/models/$r" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    fs=[s["rfilename"] for s in d.get("siblings",[]) if s["rfilename"].endswith(".gguf")]
    pref=[f for f in fs if any(k in f for k in ("Q4_0","Q4_K_M"))]
    print("  quants:", ", ".join(pref[:6]) or "none matching")
except Exception as e:
    print("  unavailable:", e)
'
done
say "DONE-CLBLAST-PREP2"
