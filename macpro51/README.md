# macpro51 — exo build notes and Intel/AMD inference findings

Everything in this directory documents one machine and two jobs done on it: bringing **exo** up to
date and getting it to build, and finding an LLM stack that actually produces tokens on hardware that
exo's MLX-only backend cannot serve.

The source of truth for the whole session is [`STATUS.md`](STATUS.md); this file is the index.

## The machine

| | |
| --- | --- |
| Host | `macpro51.local` (`192.168.0.118`), user `threaded`, macOS **11.7.11** (Big Sur) |
| CPU | 2 × Xeon X5675 — 12 cores / 24 threads, **SSE4.2 only, no AVX/AVX2/FMA** |
| RAM | 96 GB |
| GPU | Radeon RX 580, 8 GB, Metal GPUFamily macOS 2, OpenCL 1.2 (36 CU, **no `cl_khr_fp16`**) |
| Notable | Homebrew has **no x86_64 macOS bottles** for uv/node/rust; the Metal driver rejects non-page-aligned `newBufferWithBytesNoCopy` |

## exo on this machine

- Branch base is `f338f05d` (upstream `main`, 4 Nov 2026). exo was re-synced to it and rebuilt:
  `uv sync --extra mlx-none --no-dev` + `cd dashboard && npm install && npm run build`.
  Verified `exo 0.3.70`, dashboard `/` = 200, `/state` = 200, master elected, clean shutdown.
- **exo cannot run inference here, on any branch.** `src/exo/worker/engines/` holds only `mlx` and
  `image`; the six upstream branches that add a second engine all add `vllm` (CUDA/DGX, Linux only).
  A sweep of all 249 remote branches found no `cpu`, `gguf`, `ggml`, `llama` or `torch` engine.
  MLX is Apple-silicon-only, so this node is a **coordinator** (`--no-worker`).
- Toolchain that had to be installed by hand (vendors' installers, since brew has no x86_64 macOS
  bottles): rustup (1.99.1) for edition-2024, node 22.23.4 (26 will not run on Big Sur),
  uv 0.13.7 (astro installer). The `dev` dependency group cannot be installed at all —
  `basedpyright → nodejs-wheel-binaries` compiles node from source and fails. Use `uv run --no-dev exo`.

## What does run an LLM here: llama.cpp

Built from source at `~/projects/llama.cpp` (CPU, `GGML_BLAS=OFF`, `-t 12`). Key measured facts:

| model | device / build | prefill | decode |
| --- | --- | ---: | ---: |
| Qwen2.5-0.5B Q4_K_M | CPU, no-BLAS | 34.5 t/s (pp128) | 18.9 t/s |
| Qwen2.5-1.5B Q4_K_M | CPU, no-BLAS | 14.0 t/s (pp128) | 8.6 t/s |
| Mistral-7B Q4_K_M | CPU, modern build | 2.75 t/s (pp128) | 1.50 t/s |
| Mistral-7B Q4_K_M | **RX 580 via CLBlast** | **28.8 t/s (pp512)** | **4.59 t/s** |
| Mistral-7B Q4_0 | CPU, Jun-2024 build | 10.2 t/s (pp128) | 5.70 t/s |

Rules that came out of the measurements:

- **Use 12 threads, never 24.** Hyperthreads across both sockets collapse decode to 0.94 t/s.
- **`-DGGML_BLAS=OFF`** is worth ~1.8× on prefill (Accelerate's `cblas_sgemm` is a loss on this CPU).
- **7B on the GPU, small models on the CPU.** The GPU's edge grows with model size and prompt length;
  for Qwen2.5-1.5B the CPU wins (8.6 vs 6.63 t/s).
- **Modern llama.cpp decodes ~2× slower than the Jun-2024 tree on this CPU** at 7B (2.46 vs 5.50 t/s
  for Q4_0); not caused by weight repacking. Small models are unaffected.

### GPU routes, all measured

| route | result |
| --- | --- |
| **OpenCL via CLBlast** (llama.cpp `0cd6bd348`, Jun 2024) | **works on the RX 580** — best 7B prefill and decode; needs CLBlast built from source and `DYLD_LIBRARY_PATH` |
| Modern llama.cpp OpenCL backend | impossible: needs OpenCL 2.0 + `cl_khr_fp16`, and whitelists Adreno/Intel only |
| Metal (patched) | runs, but **2× slower than CPU** on every model (no simdgroup matmul on a non-Apple GPU) |
| Vulkan / MoltenVK | not pursued — LunarG's macOS SDK is a GUI installer, and MoltenVK rides Metal, which is already slower |

Two Metal patches were needed to make it run at all (`scripts/patch-metal.py`, `scripts/patch-metal2.py`):
`set_tensor` falls back to `newBufferWithBytes:` and `get_tensor` reads back through a temporary shared
buffer, because this driver rejects `newBufferWithBytesNoCopy` for non-page-aligned host pointers.

### Launchers (on the machine)

```bash
~/llm-run-gpu.sh [model] [port] [ngl]   # CLBlast + RX 580, best for 7B   (default :8080)
~/llm-run.sh     [model] [port]         # modern CPU build, best for small models
```

Both start llama.cpp's OpenAI-compatible server on `127.0.0.1`.

## Layout

- `STATUS.md` — the full session record: exo state, build recipes, every benchmark, the freeze log,
  and the traps found along the way.
- `scripts/` — every script used, in the order it was run. Remote scripts are fed to the Mac as
  `./rssh 'bash -s' < scripts/<name>.sh`; the remote login shell is zsh.
- `helpers/` — the workspace's own SSH/bench helpers (`rssh`, `ssh51.sh`, `push.sh`, `bringup.sh`,
  `bench.py`, `setconfig.py`). `rssh` is the one this work used: `-F /dev/null` (the system ssh config
  is broken by ownership) and a workspace `known_hosts`, because `$HOME` is read-only in the agent
  sandbox.

## Traps worth remembering

- **Never put a space in a model path handed to the old llama.cpp** — `$HOME` is
  `/Volumes/Sonnet Raid/...` and it truncates at the space (`failed to load model '/Volumes/Sonnet'`).
  Use a `/tmp/m/…` symlink.
- In the Jun-2024 tree the binaries are `main` and `server`, not `llama-cli`/`llama-server`, and
  `LLAMA_CLBLAST=ON` matters even for CPU-only use (prefill: 1.45 → 10.2 t/s).
- macOS here has no GNU `timeout`, and `git-lfs`/`brew`/`cargo` live in `/usr/local/bin`, which is
  **not** on a non-login SSH shell's PATH.
