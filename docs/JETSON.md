# Running exo on an NVIDIA Jetson

Verified on: **Jetson AGX Xavier**, L4T R35.5 / JetPack 5, Ubuntu 20.04.6 LTS, aarch64,
CUDA 11.4.315, GPU compute capability 7.2, tinygrad backend.

The instructions in the main [README](../README.md) assume a desktop Linux box, and several of
their assumptions do not hold on a Jetson. This page is the procedure that does.

## What is different on a Jetson

| Desktop assumption | On JetPack 5 / Ubuntu 20.04 |
| --- | --- |
| `python3` is 3.12 or newer | `python3` is **3.8.10** and `python` is **python2.7.18** |
| `python3 -m venv` works | **fails**: `ensurepip` is not available (the `python3.8-venv` package is not installed) |
| `nvidia-smi` reports the GPU | **not installed**; the GPU is queried with `tegrastats` |
| `nvcc --version` is needed | **not needed**: tinygrad compiles its kernels at run time with NVRTC, which JetPack ships |
| `pynvml` describes the GPU | **fails** with `NVMLError_LibraryNotFound`; JetPack has no `libnvidia-ml.so.1`, only a link-time stub under `/usr/local/cuda-*/targets/*/lib/stubs/` |

`install.sh` and `exo/topology/device_capabilities.py` handle all of this, so the steps below are
short. The rest of this page exists so that a failure on a different JetPack release can be
diagnosed instead of guessed at.

## 1. Get a Python 3.12

exo requires Python >= 3.12 because of [asyncio problems in earlier versions](https://github.com/exo-explore/exo/issues/5).
`install.sh` looks for one and refuses to run without it; it does not fall back to 3.8, which
cannot run exo. Any of these work:

```sh
# a conda environment (what this board uses)
conda create -n exo python=3.12

# pyenv
pyenv install 3.12 && pyenv global 3.12

# or build/install one and tell the script where it is
PYTHON=/path/to/python3.12 ./install.sh
```

Do not try `sudo apt install python3.12` first: Ubuntu 20.04 does not carry 3.12, and the
`deadsnakes` PPA is the only apt route. The script also checks that the interpreter it picks can
actually create a venv, since `python3.X-venv` is a separate package on Debian and Ubuntu and a
recent interpreter without it still cannot install anything.

## 2. Install

```sh
git clone https://github.com/exo-explore/exo.git
cd exo
./install.sh
```

`./install.sh` builds `.venv` and installs exo into it in editable mode. Run it as a script unless
you want the venv left activated in your shell, in which case `source install.sh` is equivalent.
An existing `.venv` is reused only when it is genuinely usable: a venv that has been moved from
another directory keeps the absolute shebangs of its old location, and every console script in it
— `pip` included — then fails with `bad interpreter`, so the script checks a script rather than
just the interpreter and rebuilds the venv when it is stale.

Every pinned dependency resolves from an `aarch64` wheel on this board
(`grpcio`, `pydantic-core`, `numpy`, `opencv-python`, `uvloop`, `tokenizers`, ...), so nothing is
compiled from source and an install takes a few minutes on the 8 Carmel cores, most of it
unpacking.

## 3. Check that the GPU is seen

```sh
source .venv/bin/activate
python -c "import asyncio; from exo.topology.device_capabilities import device_capabilities; print(asyncio.run(device_capabilities()))"
```

On this board that prints:

```
Model: Linux Box (NVIDIA Jetson AGX Xavier). Chip: NVIDIA Jetson AGX Xavier. Memory: 31002MB. Flops: fp32: 1.41 TFLOPS, fp16: 2.82 TFLOPS, int8: 5.64 TFLOPS
```

NVML cannot answer here, so `device_capabilities.py` falls back to the device tree
(`/proc/device-tree/compatible` carries `nvidia,jetson-xavier`) and reports the system's unified
DRAM as the memory available to the GPU — a Jetson's GPU and CPU share the same chips, so the
figure a model can use is the machine's total, not a separate VRAM size. A Jetson that the lookup
table does not know still reports its own name from `/proc/device-tree/model` rather than another
board's. On a machine where NVML does work, that path is still preferred and nothing changes.

The FLOPS figures come from the `CHIP_FLOPS` table in the same file and are the board's rated
peak; they are used for partitioning decisions relative to the other devices in the cluster.

## 4. Run something

A 1B model is a comfortable single-device test on 30 GB of shared memory:

```sh
exo --inference-engine tinygrad --run-model llama-3.2-1b \
    --prompt "Explain in one sentence what a tensor is."
```

The first run downloads the weights into `~/.exo/downloads` (about 2.5 GB for this model) and
then loads them; expect tens of seconds for the transfer and a few seconds for the load.

For the chat UI and the ChatGPT-compatible API instead:

```sh
exo --inference-engine tinygrad --disable-tui
```

`--disable-tui` is worth keeping on a board driven over SSH, since the TUI needs a real terminal.
The URLs it prints are the ones to open.

## 5. Running the test suite

```sh
.venv/bin/python -m pip install -e ".[test]"
.venv/bin/python -m pytest exo/ test/ -q
```

`conftest.py` keeps the run from stopping on collection errors: the MLX test modules are skipped
when `mlx` is absent (Apple Silicon only), and `exo/inference/test_inference_engine.py` is left out
of collection because it is a script that runs its checks at import time and that CI invokes with
`python -m exo.inference.test_inference_engine`.

Four tests fail on this board, identically on an unmodified checkout — they are not part of the
port and are listed here so a red run is not mistaken for a broken install:

- `test_device_capabilities.py::test_mac_device_capabilities_pro` — the expected string in the
  test omits the `fp32: ` prefix that `DeviceFlops.__str__` has emitted since it grew one.
- `test_topology_viz.py::test_layout_generation` — `NameError: name 'RepoFileProgressEvent' is not
  defined`; the test file never imports it.
- `test_ring_memory_weighted_partitioning_strategy.py::test_partition_rounding` — the strategy
  returns the partitions in a different order than the test expects.
- `test_new_shard_download.py::test_new_shard_download` — an unmarked `async def`, so
  pytest-asyncio refuses it on every platform. It would also download MLX weights.

`test/test_model_helpers.py`, `test/test_tokenizers.py` (the two the CI runs),
`test_map_partitions.py`, `test_network_topology_config.py`, `test_dummy_inference_engine.py` and
`test_device_capabilities.py::test_device_capabilities` all pass here.

## Limits worth knowing

- `nvcc` is not required, but the CUDA toolkit's `libnvrtc` and the driver's `libcuda.so` are:
  tinygrad compiles every kernel at run time with NVRTC. JetPack installs both, so a stock board
  needs no extra CUDA setup.
- The board's memory is shared with the CPU. `--memory` figures exo reports are the machine's
  total; leaving the desktop session running and then loading a model close to that total will
  push the whole machine into swap rather than just failing the load.
- `tegrastats` is the tool for watching the GPU (`tegrastats --interval 1000`); `nvidia-smi` does
  not exist on this platform and the README's check for it will fail.
