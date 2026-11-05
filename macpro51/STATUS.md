# macpro51 — Strata bring-up state

Where things stand, so a fresh agent can continue without re-deriving it.

## Machine

| | |
| --- | --- |
| Host | `macpro51` = `192.168.0.118` (reach it with `./ssh51.sh '<cmd>'`) |
| Hardware | Mac Pro 5,1, 2 × Xeon X5675 (x86_64, **no AVX/AVX2/FMA**; SSE4.2, POPCNT, AES; 12 physical cores / 24 threads), 96 GB RAM, Radeon RX 580 **8 GB**, Metal 2 |
| OS / SDK | macOS 11.7.11, Apple clang 13, macOS 12.1 SDK |
| Repo | `~/projects/Strata/Strata` (git, branch `main`) |
| Data | `/Volumes/Sonnet Raid/Users/threaded/projects/Strata-data` (5.5 TB free) |

`./ssh51.sh` and `./push.sh` (this directory) wrap SSH — the system `ssh_config` is broken by ownership, so
everything uses `-F /dev/null`. `push.sh <repo-relative paths>` copies edited files from `./repo/` to the Mac.

## Done and verified

**It builds** (clean from scratch, 0 errors, all targets): `strata`, `strata_ds4`, `runtime_hello`,
`dsu_ref_vs_ggml`; plus `build-vision/bin/strata-vision`. `runtime_hello` → `RESULT: all passed`;
`dsu_ref_vs_ggml` → bit-exact vs ggml. See the previous session's notes for the 9 build blockers fixed.

**It loads a model**: Qwen3.8-Flash-Next GSQ-RCO **Q2_0** (66.4 GB, 2 shards) downloaded, packed (1.4 GB) and MTP
draft layer (0.89 GB) built into `Strata-data/`. `/health` → `"loaded": true`.

Engine startup line to look for:

```
strata metal: decode window on AMD Radeon RX 580: ... wrapped (37.6 GB), 65664 cells, PLE on, ready in N ms
```

## The open problem

The first inference request **froze the machine** (unreachable, needs a physical restart). Engine warnings:

```
strata serve: 0 MiB of VRAM free with everything loaded - LOW: requests may stall
strata serve: only 0 MiB of VRAM free at the start of this request (below 512 MiB): ... the driver can page
              GPU memory to system RAM, decode falls to a few tok/s and a window may never finish (#2065)
```

Root cause: `mac_fit.engine_args()` wrote **Apple-Silicon defaults onto an 8 GB card** (`--expert-cache 64`,
`--max-context 65536`), both assuming unified memory. Aggravated by an `mlock` wiring fallback (since made
opt-in).

### It is NOT VRAM exhaustion — corrected 16:12, second hang

Two things were established after the machine came back at 15:58:

1. **The "0 MiB of VRAM free" line is an accounting artifact.** `metal/src/gpu/runtime.cpp`'s `mem_get_info`
   returns `recommendedMaxWorkingSetSize - currentAllocatedSize`, and the 37.6 GB model is wrapped as NoCopy
   buffers that count towards `currentAllocatedSize`. On a 7 GB budget the difference is negative, so the number
   is pinned at 0 no matter what `--vram-reserve-mib` / `--expert-cache` / `--max-context` say. (Reasoned from
   the code, not measured — `mtl_probe` has not been run on this card.)
2. **The freeze is a GPU hang, not paging.** `/Library/Logs/DiagnosticReports/` holds
   `Kernel_2026-11-04-153127_MacPro51.gpuRestart`: `Event: GPU Reset`, `Restart Channel: 2 Compute1`,
   `FirstPendingCB: Process ID = 31063 ... SubmitContext = Metal`, with a WindowServer
   `userspace_watchdog_timeout.spin` at the same minute. The engine's own watchdog at 16:0x reports
   `host at layer step 1; the GPU rang 0` — the GPU never completed its **first** dispatch. The driver then
   resets the GPU, WindowServer hangs and the machine freezes; a watchdog panic reboot brings it back (~25 min).

Reproduced a second time with the conservative config (4 K context, `--expert-cache auto`, 2.5 GB reserve, no
MTP), so **it is not a sizing problem**: the ported Metal kernels do not complete on this GPU.


## Fixes made, NOT yet tested (each attempt froze the machine before it could be judged)

1. `metal/src/gpu/runtime.cpp` — `mlock` wiring is now opt-in (`STRATA_METAL_WIRE_BUFFERS=1`); `useResource`
   per dispatch is what actually provides residency below macOS 15.
2. `strata_control/mac_fit.py` — VRAM-aware: `gpu_vram_gb()`, `recommend_context(ram_gb, vram_gb)`,
   `engine_args(..., vram_gb)` → `--expert-cache auto --vram-reserve-mib <25% of card>` and an 8 K context on a
   ≤12 GB card. 33 tests pass (`python3 -m unittest tools.test_setup_mac`, run locally — they mock macOS).
3. `metal/src/engine/prompt_chain.inc` — `coop_k4()` uses `compile_try`, so the Metal-4-only probe no longer
   kills the process on Metal 2 (it means "no Metal 4 layout").
4. `metal/src/mtl_rt.mm` — `serial_dispatch()`/`enc_type()`: an encoder now uses `MTLDispatchTypeSerial` on any
   GPU that is not an Apple GPU (`supportsFamily:MTLGPUFamilyApple1`), keeping the concurrent encoder only where
   the hardware submits in order anyway. `STRATA_METAL_CONCURRENT=1` opts back in. **Unverified.**
5. `metal/src/gpu/runtime.cpp` — `STRATA_GPU_TRACE=1` prints the first 400 dispatches with their kernel names.
   **Does not fire for the engine**, which dispatches through `mtl::Context` (mtl_rt.mm), not `strata::gpu`.

## Freeze log — the machine goes down and self-recovers

| Time | Report |
| --- | --- |
| 15:31:27 | `gpuRestart`, Compute1, PID 31063 (our engine) |
| 15:56:51 | watchdog `Kernel.panic` → reboot |
| 16:06:39 | `gpuRestart` (conservative config, one-token request) |
| 16:15:38 | watchdog `Kernel.panic` → reboot |
| 16:20:06 | `gpuRestart` (this time around engine load, before any request) |
| 16:35:57 | watchdog `Kernel.panic` → reboot |

Each cycle costs ~15-25 minutes of the machine. **Stop after a freeze**: do not `kill -9` the engine
mid-hang, and do not send another request on a boot that has already reset the GPU.

## Where this leaves the objective

Build: done and verified. Model: downloaded (66.4 GB), packed, loads (`ready in ~2.2 s`), `/health` loaded.
**Inference: not achieved** — no token has ever been produced on this machine, so there are no throughput
numbers, and none will be invented. The blocker is GPU-level: the Metal backend's kernels do not complete on a
Radeon RX 580 / Metal 2, and each attempt resets the card and takes the machine down.

## Next steps when the machine is reachable

Run `./bringup.sh` (waits for the host, pushes, rebuilds, rewrites the config with the safe settings, starts the
server and **refuses to send a request while `VRAM free` is 0**). Then benchmark with `bench.py` — short prompt
first. Measure decode and prompt tok/s; report against docs/MAC.md (M5 Max ≈119 tok/s decode; 32 GB M4 streaming
≈14 tok/s).

Two env settings the config now needs on this machine (Metal 2 / macOS 11):

- `STRATA_METAL_PROMPT_GEMM=0` — `MetalPerformancePrimitives` is macOS 26; there is no prompt GEMM here.
- `STRATA_METAL_PROMPT=window` — prompts run through the decode window instead. Expect slow prefill.

---

# Exo update + build (separate track, 4 Nov ~16:45 onward)

A second, unrelated job on this machine: `~/projects/Exo/exo` (remote
`https://github.com/exo-explore/exo.git`, branch `main`) brought up to date and built.

## Update: DONE

- Before: `a605e233` 2025-02-18 (old Python-only layout, 968 commits behind).
- `git pull --ff-only` → `55eebeed` 2026-11-03, `main == origin/main`. Version now `0.3.70`.
- The project is now a **Rust + Python rewrite**: `Cargo.toml` workspace (`rust/exo_rs`,
  `rust/networking`), `src/exo`, Svelte dashboard in `dashboard/`, `uv` workspace with `uv.lock`.
- Working tree clean; only an untracked `exo.egg-info/` remains from the old `pip install -e .`.
- **PATH trap, cleared:** `git-lfs 3.6.1`, `brew 4.4.21` and `cargo 1.84.1` live in `/usr/local/bin`,
  which is *not* on the PATH of a non-login SSH shell (`/usr/bin:/bin:/usr/sbin:/sbin`). Without it
  every `git status` dies with `git-lfs filter-process: git-lfs: command not found`, which looks like
  a dirty tree. Export `PATH=/usr/local/bin:$PATH` in every remote call.

## Build: DONE 5 Nov 05:30 — coordinator/master only, no inference

Builds and **runs**. Verified in the same session as this note:

```
HEAD 55eebeed, working tree clean (only untracked exo.egg-info/)
rustc 1.99.1 (~/.cargo, rustup)   uv 0.13.7 (~/.local/bin)   node v22.23.4   npm 10.9.9   python 3.13.2 (.venv)
dashboard/build 3.6 MB            target/ 1.6 GB             site-packages/exo_rs/exo_rs.cpython-313-darwin.so
.venv/bin/exo --version  ->  exo 0.3.70
smoke: .venv/bin/exo --no-worker --no-downloads  ->  GET / = 200 (<title>EXO</title>), GET /state = 200 (valid JSON),
       "Node elected Master", clean SIGTERM shutdown, no MLX/exception lines in the log
```

### Three environment constraints that shaped the build

1. **Homebrew cannot install any of the prerequisites here.** The current formulae publish **no
   x86_64 macOS bottles at all** (uv/node/rust offer only arm64 macOS + x86_64/arm64 Linux), so
   `brew install uv node` / `brew upgrade rust` would compile from source — hours, and the node
   build fails outright. Checked with the Homebrew JSON API before installing anything, which is
   why no time was lost to it. Used the vendors' own installers instead (no `sudo`, all under
   `$HOME`, nothing touched in `/usr/local`):
   - rust: **rustup** → `~/.cargo` (1.99.1). This is what upstream's README documents anyway, and it
     is the only way to get edition-2024 support; the Homebrew rust stays at 1.84.1, untouched.
   - node: official **darwin-x64 tarball v22.23.4** → `~/.local/opt/node`. Node 26 (current LTS)
     will not run: it is built for macOS 13.5 and dies with
     `dyld: Symbol not found: __ZNKSt3__115basic_stringbuf...`. Node 22 is the newest that runs on 11.7.
   - uv: **astral installer** → `~/.local/bin` (0.13.7). It does run on Big Sur (the installer skips
     its sha256 check because the box has no `sha256sum`).
2. **The dev dependency group cannot be installed.** `uv sync` (default, includes `dev`) fails building
   `nodejs-wheel-binaries 25.2.1rc0`, pulled in by `basedpyright`: it compiles node from source and
   `make[1]: *** [ncrypto.o] Error 1` / `*** CMake build failed` against the Big Sur SDK. Hence
   `uv sync --extra mlx-none --no-dev`. Consequence: **ruff, pytest, basedpyright and the rest of the
   dev group are NOT installed**, so the project's test suite cannot be run as-is.
   Because of this, README's `uv run exo` re-syncs and dies the same way — use
   `uv run --no-dev exo` (verified) or `.venv/bin/exo` directly.
3. **MLX is impossible on this hardware.** It is Apple-silicon-only, so the documented macOS path
   `uv sync --extra mlx` cannot apply; `--extra mlx-none` is upstream's own "master runs without MLX"
   path (`pyproject.toml:49`, `src/exo/worker/engines/mlx/models/spec.py`). This node can coordinate a
   cluster but cannot run inference itself.

### Runtime recipe on this box

```bash
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
cd ~/projects/Exo/exo
.venv/bin/exo --no-worker --no-downloads      # coordinator; dashboard+API on http://localhost:52415
```

`exo.egg-info/` is an untracked leftover of the pre-update `pip install -e .`; safe to delete.
Remote helper scripts from the build (`~/exo-stageA2.sh`, `~/exo-stageA3.sh`, `~/exo-stageB.sh`,
`~/exo-stageC2.sh`, `~/exo-smoke.sh`, plus their `.log`/`.pid` files) are inert and can be removed.

### The 4 Nov interruption, for the record

The first prerequisite install (`brew install uv node && brew upgrade rust`, chosen at the time) died
at 17:10 when the machine dropped off the network — consistent with this machine's documented
GPU-hang → watchdog-panic cycling, and it needed a physical power cycle. Nothing survived it: no uv,
no node, rust still 1.84.1, no partial brew state. The repo was untouched (`55eebeed`, clean).
`scripts/wait-for-host.sh [seconds]` polls for the machine; local stage scripts are in `scripts/`.


---

# 5 Nov, second pass: exo re-synced + a working LLM on CPU

## exo: updated again, and definitively cannot infer on this machine

`main` moved on by 9 commits: `55eebeed` → **`f338f05d`** (4 Nov, "Remove nodes only when membership
says they are gone..."). Rebuilt: `uv sync --extra mlx-none --no-dev` (the `rust/networking` crate
changed, so `exo_rs` recompiled, 2m52s) + `cd dashboard && npm install && npm run build`. Verified
`exo 0.3.70`; the coordinator smoke test still gives `/` = 200 and `/state` = 200.

Upstream is now **249 remote branches**. Newest is `origin/dataplane/serving-off-the-master`
(5 Nov, "Wire version 3: serving without the master..."), then `origin/main`, then the `deploy/*`
series (`deployments`, `durable`, `leave-grace`, `typed-removal`, `dashboard`),
`identity/persistent-node-id`, `fix/deepseek-v41-gather-waits-on-cpu` and a long `perf/*` tail.

**No branch can run inference on this hardware.** `src/exo/worker/engines/` on main holds only
`mlx` and `image`. Six branches add a second engine and it is `vllm` in every case
(`andrei/dgx-mac-usb-fix`, `leo/dgx-spark-integrations`, `leo/prefill-decode-really`,
`leo/use-sm121-branch`, `merge-attempt`, `testing`) — all from Mar–Apr 2026 and all CUDA/DGX, i.e.
Linux + NVIDIA. A sweep of all 249 branches' `engines/` directories found no `cpu`, `gguf`, `ggml`,
`llama` or `torch` engine anywhere (`origin/leo/gguf-maybe` is MLX-side work, not a GGUF runtime).
So on this Intel Mac exo stays a **coordinator only** (`--no-worker`): the MLX backend is
Apple-silicon-only and nothing upstream replaces it. `src/exo/testkit/stub/engine.py` (new in this
pull) is a test double, not an inference backend.

## LLM that does run: llama.cpp on the CPU

Built from source at `~/projects/llama.cpp` (ggml-org, `8bed7cf`, 4 Nov) with AppleClang 13:

```bash
/usr/local/Cellar/cmake/3.31.5/bin/cmake -B build -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=ON -DGGML_NATIVE=ON
/usr/local/Cellar/cmake/3.31.5/bin/cmake --build build -j12
```

Note `cmake` is **not linked**: use `/usr/local/Cellar/cmake/3.31.5/bin/cmake` (a `4.4.5` Cellar dir
exists but is incomplete). `GGML_NATIVE=ON` picks up SSE4.2 on Westmere and no AVX paths.

Models in `~/models` (all downloaded from Hugging Face, GGUF magic verified):
`Qwen2.5-0.5B-Instruct-Q4_K_M` (379 MB), `Qwen2.5-1.5B-Instruct-Q4_K_M` (940 MB),
`Qwen2.5-1.5B-Instruct-Q4_0` (897 MB).

### Measured throughput (llama-bench, 12 threads, 3 reps)

| model | build | pp128 t/s | tg64 t/s |
| --- | --- | ---: | ---: |
| Qwen2.5-0.5B Q4_K_M | BLAS (Accelerate) | 25.6 | 18.9 |
| Qwen2.5-0.5B Q4_K_M | **no BLAS** | **34.5** | 18.9 |
| Qwen2.5-1.5B Q4_K_M | BLAS | 7.7 | 8.7 |
| Qwen2.5-1.5B Q4_K_M | **no BLAS** | **14.0** | 8.6 |
| Qwen2.5-1.5B Q4_0 | BLAS | 7.6 | 7.1 |

Conclusions that should govern any future tuning here:

1. **`-DGGML_BLAS=OFF` is worth ~1.8× on prompt processing** (14.0 vs 7.7 t/s on the 1.5B) and is
   neutral on decode. Accelerate's `cblas_sgemm` is a loss on this CPU; ggml's own threading is
   better. The canonical `build/` is the no-BLAS one.
2. **Use 12 threads, never 24.** Hyperthreads across two sockets destroy decode:
   `-t 24` gave **0.94 t/s** vs 8.74 at `-t 12`. Sweep on the 0.5B: 6 → 14.6, 8 → 17.8, 10 → 19.9,
   12 → 18.5, 16 → 18.7 tg t/s, so 10–12 is the plateau.
3. **Q4_K_M beats Q4_0** here (8.6 vs 7.1 tg, and 14.0 vs 7.6 pp on the BLAS build), despite Q4_0's
   simpler dequant.
4. Decode is memory-bound at ≈8.3 GB/s effective and prefill is compute-bound at ≈25–35 GFLOPS —
   which is what a 2010 Westmere with SSE4.2 but no AVX gives you. Expect roughly `t/s ≈ 13 / B` for
   decode at Q4_K_M: 0.5 B → 19, 1.5 B → 8.6, so a 7 B would land near 1.9 and a 3 B near 4.5.

### Verified generation

```
1.5B Q4_K_M, 200 tokens, -t 12:      [ Prompt: 14.0 t/s | Generation: 8.3 t/s ]
0.5B Q4_K_M, 96 tokens,  -t 12:      [ Prompt: 21.8 t/s | Generation: 18.7 t/s ]
```

Both produced fluent, on-topic English (the 1.5B's *facts* about the Mac Pro were wrong — a 1.5B
limitation, not a harness one).

### How to run it

```bash
~/llm-run.sh                                  # OpenAI-compatible server on 127.0.0.1:8080, 12 threads, 8 K ctx
~/llm-run.sh ~/models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf 8081
curl -s localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"hello"}],"max_tokens":32}'
```

Verified: `/health` 200 two seconds after start, `/v1/chat/completions` 200 with a real reply,
clean SIGTERM. For one-shot CLI use:
`~/projects/llama.cpp/build/bin/llama-cli -m <model> -t 12 -n 200 -p '...' --no-display-prompt`.
(There is no `timeout` binary on this macOS; `llama-cli` needs stdin redirected or it sits in chat
mode.)

## Not attempted: the GPU

The RX 580 has never been exercised by llama.cpp here. Its Metal backend does not officially support
Intel + AMD, and this exact card has already reset itself and hung the machine several times under
Strata's own Metal kernels today (see the freeze log above), each costing a power cycle. A Metal
build (`-DGGML_METAL=ON`, `-ngl N`) is a plausible 5–10× on decode, but it is an experiment with a
real chance of taking the machine down, so it needs the owner's go-ahead rather than a silent attempt.

## 5 Nov, third pass: the RX 580 / OpenCL question, answered with evidence

The card is real and exposed: `system_profiler` shows **Radeon RX 580, PCIe slot 2, 8 GB, Metal GPUFamily
macOS 2**, and my OpenCL enumerator (`scripts/gpu-probe.sh`, plain clang + `-framework OpenCL`) gets:

```
platform[0]: Apple | OpenCL 1.2 (Aug 29 2022 02:56:50)
  device[1]: AMD Radeon RX 580 Compute Engine | OpenCL 1.2 | driver 1.2 (Jul 29 2025)
             mem 8192 MB | CU 36 | WG 256 | available=1 | cl_khr_fp16: NO
```

So yes — 36 compute units of OpenCL. llama.cpp does have a real OpenCL backend, and `GGML_OPENCL=ON`
configures and even embeds its `.cl` kernels ("Including OpenCL backend"). It still cannot run here,
and the failure is four-deep:

1. **`#include <CL/cl.h>` not found** — Apple ships the headers only inside
   `OpenCL.framework/Headers` (cl.h, cl_ext.h, cl_platform.h, gcl.h), not as `CL/*.h`. Fixed with a shim
   (`ocl-shim/CL/*.h`, `-DCMAKE_CXX_FLAGS=-I<shim>`).
2. **Then it does not compile**: 20 errors before clang's limit, all missing **OpenCL 2.0** API —
   `cl_name_version`, `cl_device_svm_capabilities`, `CL_DEVICE_OPENCL_C_ALL_VERSIONS`,
   `CL_PROFILING_COMMAND_COMPLETE`. Apple's SDK headers are 1.2.
3. **And it could not link anyway**: `nm -gU` on
   `/System/Library/Frameworks/OpenCL.framework/Versions/A/OpenCL` shows **none** of the 2.0 entry
   points the backend calls — `clCreateCommandQueueWithProperties`, `clSVMAlloc`, `clSVMFree`,
   `clCreateProgramWithIL`, `clCreateImage`, `clEnqueueSVMMemcpy` are all missing.
4. **And even with a patched build the device would be refused at runtime**:
   `ggml_opencl_is_device_supported()` (ggml/src/ggml-opencl/ggml-opencl.cpp:~8930) rejects on three
   independent grounds — the vendor whitelist is Adreno/Qualcomm/Intel only ("unsupported GPU"),
   "OpenCL 2.0 or above is required", and "device does not support FP16" (`cl_khr_fp16`).
   `GGML_OPENCL_USE_ADRENO_KERNELS=OFF` only removes one of those three gates.

Verdict: **llama.cpp's OpenCL backend is an Adreno/Intel OpenCL 2.0+ target.** Apple froze OpenCL at
1.2 on Big Sur with no fp16 on this Polaris card, so OpenCL cannot use the RX 580 here regardless of
how it is compiled. The failed build tree is `~/projects/llama.cpp/build-ocl` + `ocl-shim` (kept as
evidence; the working CPU build in `build/` is untouched).

### What could still reach the GPU (not attempted, needs a decision)

| route | how | state |
| --- | --- | --- |
| **Metal** (`GGML_METAL=ON`) | llama.cpp's main GPU backend; known to work on Intel Macs with AMD dGPUs (iMac Pro Vega), partial feature fallbacks | one build flag away; **card has already GPU-reset under Strata's Metal kernels today** |
| **Vulkan via MoltenVK** | `GGML_VULKAN=ON` + prebuilt Khronos MoltenVK dylib + vendored vulkan headers | more setup, and MoltenVK translates to Metal, so same driver risk |
| **CLBlast-era llama.cpp** (pre mid-2023, commit before the CLBlast backend was removed) | true OpenCL 1.2 path, historically fast on RX 580 (7B Q4 ≈ 20-30 t/s); needs CLBlast built from source | code too old for Qwen2.5 — would need a Llama-2/Mistral-7B-era model |

## 5 Nov, fourth pass: all three GPU routes measured — the RX 580 IS usable, via CLBlast

The prompt was right that the card exists and OpenCL should work. Modern llama.cpp's OpenCL backend is
a dead end, but the **CLBlast-era build does use the RX 580**, and on 7B models it beats the CPU.

### Route results (all measured with llama-bench on this machine, 12 threads)

| route | 7B Q4_0 pp128 / tg64 | 7B Q4_K_M pp512 / tg | verdict |
| --- | --- | --- | --- |
| **CLBlast + RX 580** (Jun-2024 build, `-ngl 99`) | 10.8 / **5.43** | **28.8** / **4.59** | **works, fastest prefill, fastest 7B Q4_K_M decode** |
| same build, CPU (`-ngl 0`) | 10.2 / 5.70 | — / 2.22 | old-era CPU kernels are fast in decode |
| same build, CPU-only compile (no CLBlast) | 1.45 / 5.50 | — | prefill collapses without CLBlast (old BLAS path) |
| **Metal** (Nov-2026 build, `-ngl 99`, patched) | 8.3 / 1.76 | 7.95 / 1.74 | works but **always slower than CPU** |
| **modern CPU** (Nov-2026, no-BLAS) | 10.1 / 2.46 | 9.7 / 1.50 (Q4_K_M) | best for small models only |
| modern OpenCL backend | — | — | cannot build (needs OpenCL 2.0 + fp16, Adreno/Intel only) |
| Vulkan/MoltenVK | — | — | not attempted: LunarG's macOS SDK is a GUI installer (`installer.dat`), and MoltenVK translates to Metal, which is 2x *slower* than CPU here |

Small models invert the result — for Qwen2.5-1.5B Q4_K_M: modern CPU 8.6 tg vs GPU 6.63 tg, so **keep
small models on the CPU**. The GPU's win grows with model size (memory bandwidth: RX 580 ≈ 256 GB/s vs
the Xeon's effective ~20 GB/s) and with prompt length (prefill is where it shows: 28.8 vs 9.7 t/s).

### What had to be built (all on the machine, nothing system-wide)

1. **CLBlast 1.7.0** at `~/projects/CLBlast` (`-DSAMPLES=OFF`, OpenCL via the framework, headers via the
   `CL/*.h` shim). This is the piece that makes OpenCL 1.2 usable — CLBlast only needs 1.1/1.2.
2. **llama.cpp at `0cd6bd348` (4 Jun 2024)** — the last tree that still contains
   `ggml-opencl.cpp` with `clblast::Gemm`; the modern OpenCL backend replaced it. Built in a **separate
   git worktree** `~/projects/llama-clblast` (modern clone untouched) with
   `-DLLAMA_CLBLAST=ON -DCMAKE_PREFIX_PATH=~/projects/CLBlast/dist`.
   Runtime needs `DYLD_LIBRARY_PATH=~/projects/CLBlast/dist/lib`.
   Verified end to end: `ggml_opencl: selecting device: 'AMD Radeon RX 580 Compute Engine'`,
   `llm_load_tensors: offloaded 33/33 layers to GPU`, coherent text out, 5.22 tok/s in `main`.
3. Models: `mistral-7b-instruct-v0.2` Q4_0 (3.8 GB) and Q4_K_M (4.1 GB) from TheBloke. The old build
   also loads **Qwen2.5** (arch `qwen2`) — it just isn't faster there.

Launchers: `~/llm-run-gpu.sh [model] [port] [ngl]` (CLBlast + RX 580) and `~/llm-run.sh` (modern CPU).

### Two traps worth remembering

- **Never put a space in the model path.** `$HOME` is `/Volumes/Sonnet Raid/...`; the old llama.cpp
  truncates the path at the space (`failed to load model '/Volumes/Sonnet'`). Use a `/tmp/m/...` symlink.
- **The old build's OpenCL prefill needs CLBlast even at `-ngl 0`**: 1.45 vs 10.2 t/s pp128. If you
  rebuild that tree, keep `LLAMA_CLBLAST=ON` even for CPU-only use.
- In that era the CLI binary is `main` and the server is `server` (not `llama-cli`/`llama-server`).

### Side finding: modern llama.cpp is ~2x slower than the 2024 build on this CPU

Same model, same quant, same 12 threads: 7B Q4_0 decode is **2.46 t/s (Nov 2026)** vs **5.50-5.70 t/s
(Jun 2024)**. Not caused by Weight repacking (`--repack 0` gives 2.26). Not the GPU (the CPU-only
compile of the old tree also gives 5.50). Something in ggml-cpu's non-AVX kernel selection regressed
between those eras. It does not affect small models (Qwen2.5-1.5B: 8.6 modern vs 8.78 old), so it is
specific to heavier per-token work. If 7B CPU speed matters, the 2024 tree is the faster engine here.

### Metal detail (for the record)

Modern Metal needed two local patches in `ggml/src/ggml-metal/ggml-metal-device.m` before it would run
at all — this driver rejects `newBufferWithBytesNoCopy` for non-page-aligned host pointers:
`set_tensor` now falls back to `newBufferWithBytes:`, and `get_tensor` reads back through a temporary
shared buffer. With those, Metal runs but is 2x slower than CPU on every model tried (no simdgroup
matrix ops on a non-Apple GPU: "tensor API disabled for pre-M5 and pre-A19 devices"). The patches are
local to `~/projects/llama.cpp/build-metal`'s source tree and documented in `scripts/patch-metal*.py`.
