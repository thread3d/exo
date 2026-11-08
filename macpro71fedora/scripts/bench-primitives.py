"""Time the MLX primitives a decode step is built from, per dtype.

Run it through the environment script so MLX resolves libstdc++ from the system:

    . macpro71fedora/scripts/env.sh
    "$UV" run --no-sync python macpro71fedora/scripts/bench-primitives.py

MLX is lazy, so every timing below evaluates the result inside the measured region; timing
without `mx.eval` measures nothing at all.
"""

import time
from collections.abc import Callable
from functools import partial

import mlx.core as mx

MATMUL_SIZE = 1024
GEMV_SIZE = 4096
ELEMENTWISE_ELEMENTS = 4_000_000


def bench(operation: Callable[[], mx.array], repeat: int = 5) -> float:
    """Seconds per call, with the work forced to complete each time."""
    mx.eval(operation())
    start = time.perf_counter()
    for _ in range(repeat):
        mx.eval(operation())
    return (time.perf_counter() - start) / repeat


def report_matmul() -> None:
    size = MATMUL_SIZE
    left = mx.random.uniform(shape=(size, size)).astype(mx.float32)
    right = mx.random.uniform(shape=(size, size)).astype(mx.float32)
    seconds = bench(lambda: mx.matmul(left, right))
    print(
        f"fp32 matmul {size}: {seconds * 1e3:8.2f} ms  "
        f"{2 * size**3 / seconds / 1e9:7.1f} GFLOP/s"
    )


def report_gemv_per_dtype() -> None:
    """A decode step's arithmetic is a (1, K) x (K, N) GEMV."""
    for dtype, name in (
        (mx.float16, "fp16"),
        (mx.bfloat16, "bf16"),
        (mx.float32, "fp32"),
    ):
        activation = mx.random.uniform(shape=(1, GEMV_SIZE)).astype(dtype)
        weight = mx.random.uniform(shape=(GEMV_SIZE, GEMV_SIZE)).astype(dtype)
        seconds = bench(partial(mx.matmul, activation, weight))
        print(f"{name} gemv {GEMV_SIZE}: {seconds * 1e3:8.2f} ms")

        elementwise_input = mx.random.uniform(shape=(ELEMENTWISE_ELEMENTS,)).astype(
            dtype
        )
        seconds = bench(partial(mx.multiply, elementwise_input, elementwise_input))
        element_size = 4 if dtype == mx.float32 else 2
        bandwidth = 2 * ELEMENTWISE_ELEMENTS * element_size / seconds / 1e9
        print(
            f"  {name} elementwise {ELEMENTWISE_ELEMENTS}: {seconds * 1e3:8.2f} ms  "
            f"{bandwidth:6.1f} GB/s"
        )


def report_quantized_gemv() -> None:
    """What a 4-bit and an 8-bit model's linear layers cost, in bytes moved per token."""
    weight = mx.random.uniform(shape=(GEMV_SIZE, GEMV_SIZE)).astype(mx.float32)
    activation = mx.random.uniform(shape=(1, GEMV_SIZE)).astype(mx.float32)
    for bits in (4, 8):
        quantized, scales, biases = mx.quantize(weight, group_size=64, bits=bits)
        seconds = bench(
            partial(
                mx.quantized_matmul,
                activation,
                quantized,
                scales,
                biases,
                transpose=False,
                group_size=64,
                bits=bits,
            )
        )
        moved_bytes = GEMV_SIZE * GEMV_SIZE * bits / 8
        print(
            f"{bits}-bit quantized gemv {GEMV_SIZE}: {seconds * 1e3:8.2f} ms  "
            f"{moved_bytes / seconds / 1e9:5.1f} GB/s"
        )


def main() -> None:
    print(f"device: {mx.default_device()} {mx.device_info()}")
    report_matmul()
    report_gemv_per_dtype()
    report_quantized_gemv()


if __name__ == "__main__":
    main()
