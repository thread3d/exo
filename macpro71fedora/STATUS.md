# exo on Mac Pro 7,1 / Fedora — session record

Everything here was measured on this machine. Numbers are wall-clock, on an idle node, with the
node and the benchmark both running on the CPU.

- Host: `MacPro71Fedora`, Fedora Linux 44, kernel 7.2.15-310.t2.fc44.x86_64
- CPU: Intel Xeon W-3275, 28C/56T, 2.5 GHz base, 4.6 GHz max
- RAM: 251 GiB
- GPU: 2 × Radeon Pro W6800X, 1 × Radeon Pro Vega II; ROCm 7.1.1 runtime + OMP installed,
  no `hipcc` (no HIP compiler)
- Python: 3.13.9; exo: 0.3.70, wire version 7; MLX: `mlx-cpu` 0.32.4

## Result

exo builds and runs on this machine as a **single-node cluster on the CPU**:

- `uv sync --locked --python 3.13 --extra mlx-cpu` builds `exo_rs` (maturin) and installs MLX's
  Linux CPU wheel. `dashboard` builds with `npm install && npm run build`.
- A node reaches master election, serves the dashboard and 56 API paths on port 52415, and lists
  158 model cards for its `MlxCpu` backend.
- `POST /place_instance` downloads a model, starts a runner, loads it, warms it up, and the
  instance serves.
- `POST /v1/chat/completions` returns a real completion (reasoning tokens included) from the
  model. A 16-token reply to a one-line prompt took 138 s.

Two things block *usable* inference, and both are understood — see the next sections.

## Build environment

Three problems, all specific to this machine, none of them exo bugs:

### 1. The system `uv.toml` needs a newer uv than conda's

`/etc/uv/uv.toml` (from the Fedora `uv` RPM) sets `system-certs = true`. The `uv` on `PATH` is
conda's 0.9.24, which does not know that key and refuses to run at all:

```
error: Failed to parse: `/etc/uv/uv.toml`
  Caused by: TOML parse error at line 29 ... unknown field `system-certs`
```

Use `/usr/bin/uv` (0.13.5). `scripts/env.sh` exports it as `$UV`.

### 2. A conda interpreter puts an old `libstdc++` in front of MLX

`uv` created `.venv` from conda's `python3.13`. conda's interpreter has
`DT_RPATH=$ORIGIN/../lib`, and `DT_RPATH` is searched for *every* later `dlopen`, ahead of
`LD_LIBRARY_PATH`. So a process started from that interpreter that has already loaded anything
linking `libstdc++` pins `libstdc++.so.6` to conda's copy (`libstdc++.so.6.0.29`, max
`GLIBCXX_3.4.29`), and MLX then cannot find `GLIBCXX_3.4.30`:

```
Runner error: ImportError: /home/threaded/miniconda3/bin/../lib/libstdc++.so.6:
version `GLIBCXX_3.4.30' not found (required by .../mlx/lib/libmlx.so)
```

The node starts fine; only the *runner subprocess* fails, because only it imports MLX. Note that
`LD_LIBRARY_PATH` does **not** help — `DT_RPATH` wins. Two ways out:

- **Workaround (what `scripts/env.sh` does today):**
  `LD_PRELOAD=/usr/lib64/libstdc++.so.6`, which satisfies the SONAME with the system copy first.
- **Proper fix:** build the virtualenv from a standalone CPython 3.13 (`uv python install 3.13`)
  rather than a conda one. Nothing in exo needs to change.

### 3. `$HOME` is read-only inside the session sandbox

Not a property of the machine, but of this session: every XDG directory exo writes to is pointed
inside the workspace by `scripts/env.sh` (`XDG_{CONFIG,DATA,CACHE,STATE}_HOME`,
`EXO_DEFAULT_MODELS_DIR`, `HF_HOME`, `UV_CACHE_HOME`). On a normal login this is unnecessary.

## Inference speed

### The model runs, and then it crawls

| What | Time |
|---|---|
| Qwen3-0.6B-4bit, `mlx_lm.generate`, 8 tokens | 0.24 tok/s (4.2 s/token) |
| Same model, one forward pass, single token | 3.55 s |
| Same model, 8-token prefill | 28.3 s (≈ 8 × one token) |
| exo `/v1/chat/completions`, 16 tokens | 138 s |
| Runner initialisation (load + warmup) | 329 s |

The prefill number is the tell: 8 tokens cost 8× a single token, so nothing is being batched.
Whatever the arithmetic is, the model is spending its time per token, not per layer of parallel work.

### Cause 1 — MLX's x86 CPU backend does not use BLAS for fp16, and emulates fp16 arithmetic

`libmlx.so` from `mlx-cpu` links `libblas-bd8a282c.so.3` and `liblapack-86b2c207.so.3`. Those are
the **Netlib reference** implementations (683 KB and 7.6 MB, single-threaded, no SIMD), not
OpenBLAS. Only `float`/`double` matmul goes through them at all; `float16` and `bfloat16` use
MLX's own `simd_fp16`/`simd_bf16` kernels, which are written for Apple's CPUs.

Measured on 1024² and 4096² shapes:

| Operation | Throughput |
|---|---|
| MLX `float32` matmul 1024³ | 3.6 GFLOP/s |
| numpy `float32` matmul 1024³ (bundled OpenBLAS, 32 threads) | 1383 GFLOP/s |
| MLX `float32` matmul 1024³ with FlexiBLAS-OpenMP preloaded | 9.9 GFLOP/s |
| MLX elementwise, `float32` | 21.6 GB/s |
| MLX elementwise, `bfloat16` | 7.0 GB/s |
| MLX elementwise, `float16` | **0.8 GB/s** |
| MLX gemv 4096², `float32` | 10.0 ms |
| MLX gemv 4096², `bfloat16` | 36.9 ms |
| MLX gemv 4096², `float16` | **66.0 ms** |

`float16` is ~27× slower than `float32` per element: on x86 there is no native fp16 arithmetic and
MLX's kernel path is scalar. Every MLX model card in exo is loaded with `float16` activations, so
*every* multiply-add that is not a quantized matmul runs on this worst path. That is the 3.55 s.

Preloading Fedora's FlexiBLAS over the bundled reference BLAS helps `float32` matmul 2.7× and
nothing else, because the quantized and fp16 kernels never reach BLAS.

### Cause 2 — 4-bit quantized matmul is slower per byte than 8-bit on this backend

| | Time for one 4096×4096 GEMV | Effective bandwidth |
|---|---|---|
| 4-bit | 5.29 ms | 1.6 GB/s |
| 8-bit | 3.91 ms | 4.3 GB/s |

So an 8-bit model reads twice the bytes but decodes faster per token than the same model at 4-bit
on this backend — the 4-bit kernel is scalar while the 8-bit one is not.

### What fixes it: `float32` activations

Same model, same node, only the parameters' dtype changed:

| Model dtype as loaded | Decode |
|---|---|
| `float16` (what MLX gives you) | 3559 ms/token |
| `bfloat16` | 3565 ms/token |
| `float32` | **438 ms/token** |

8.1× faster. The quantized matmuls are unaffected (they measure the same at either activation
dtype), and everything around them — attention, norms, activations, the logits pass — moves to the
path where MLX's x86 backend is not being emulated.

### The GPU is not reachable from exo today

Three AMD GPUs and a ROCm 7.1.1 runtime are present, but:

- MLX has Metal, CUDA and CPU backends; there is **no ROCm backend**.
- exo's only other engine, `vllm`, is CUDA-only, and `src/exo/worker/engines/` holds just `mlx`
  and `image`, both MLX.
- ROCm here is runtime-only (no `hipcc`), so nothing could be compiled for the GPUs even with a
  backend.

An engine that could use these GPUs (llama.cpp with Vulkan or HIP, for instance) would be a new
engine in `src/exo/worker/engines/`, not a configuration change.

## Verification

What was actually run on this branch, and what it showed:

```bash
# build
uv sync --locked --python 3.13 --extra mlx-cpu      # exo_rs builds, mlx-cpu 0.32.4 installs
(cd dashboard && npm install && npm run build)      # site written to dashboard/build

# node
uv run exo                                          # "Dashboard & API Ready", :52415
curl -s localhost:52415/openapi.json | jq '.paths | length'    # 56
curl -s localhost:52415/models | jq '.data | length'           # 158 cards for MlxCpu

# inference
curl -X POST localhost:52415/place_instance -d '{"model_id":"mlx-community/Qwen3-0.6B-4bit"}'
#   -> download 343 MB, runner load + warmup, "runner ready"
curl -X POST localhost:52415/v1/chat/completions -d '{...}'    # real completion, 16 tokens/138 s
```

## Next steps

1. Make the `MlxCpu` backend load models with `float32` activations. Measured 8.1× on the same
   model; it is the single biggest lever on this machine, and it is a change to exo rather than to
   MLX. `src/exo/worker/engines/mlx/` owns model loading (`load_mlx_items`).
2. Rebuild the virtualenv on a standalone CPython 3.13 so `LD_PRELOAD` is not needed.
3. Consider `mlx-cpu`'s reference-BLAS linkage: a build that binds OpenBLAS instead would lift
   `float32` matmul by another ~2.7× where it is used.
4. Multi-device: this is a one-node cluster. A second exo node on the LAN would exercise placement,
   sharding and the ring transport on Linux for the first time, but every node needs a non-conda
   interpreter before its runners can import MLX.
