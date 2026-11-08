"""Time a whole model: load, one forward pass, and decode steps with a KV cache.

    . macpro71fedora/scripts/env.sh
    MODEL_PATH="$EXO_DEFAULT_MODELS_DIR/mlx-community--Qwen3-0.6B-4bit" \
        "$UV" run --no-sync python macpro71fedora/scripts/bench-model.py

Pass `--dtype fp32` to measure the same model with 32-bit activations, which is what MLX's x86
CPU backend prefers (see STATUS.md).
"""

import argparse
import time

import mlx.core as mx
import mlx.nn as nn
from mlx_lm import load
from mlx_lm.models.cache import make_prompt_cache

PROMPT_TOKENS = [[1, 2, 3, 4, 5, 6, 7, 8]]
DECODE_TOKEN = [[1]]
DECODE_STEPS = 3
PREFILL_TOKENS = (8, 32, 128)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model_path", help="local path of a converted MLX model")
    parser.add_argument(
        "--dtype",
        choices=("as-loaded", "bfloat16", "float32"),
        default="as-loaded",
        help="dtype to cast the model's parameters to before timing",
    )
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()

    load_start = time.perf_counter()
    model, _tokenizer = load(arguments.model_path)
    mx.eval(model.parameters())
    print(f"load: {time.perf_counter() - load_start:.1f}s")

    if arguments.dtype != "as-loaded":
        model.set_dtype(mx.bfloat16 if arguments.dtype == "bfloat16" else mx.float32)
        mx.eval(model.parameters())

    inner = getattr(model, "model", model)

    start = time.perf_counter()
    mx.eval(inner(mx.array(PROMPT_TOKENS)))
    print(
        f"forward ({len(PROMPT_TOKENS[0])} tokens): {time.perf_counter() - start:.2f}s"
    )

    cache = make_prompt_cache(model)
    mx.eval(inner(mx.array(DECODE_TOKEN), cache))  # warm up the shapes
    start = time.perf_counter()
    for _ in range(DECODE_STEPS):
        mx.eval(inner(mx.array(DECODE_TOKEN), cache))
    per_token = (time.perf_counter() - start) / DECODE_STEPS
    print(f"decode ({arguments.dtype}): {per_token * 1e3:.0f} ms/token")

    report_prefill(model, inner, arguments.dtype)


def report_prefill(model: nn.Module, inner: nn.Module, dtype: str) -> None:
    """How prefill scales with prompt length.

    On MLX's x86 CPU backend it does not scale at all: each token of the prompt costs what a
    decode step costs, because the quantized matmul re-reads the weights for every row instead
    of reusing them across the batch.
    """
    print(f"prefill ({dtype}):")
    for length in PREFILL_TOKENS:
        ids = mx.array([list(range(1, length + 1))])
        start = time.perf_counter()
        mx.eval(inner(ids, make_prompt_cache(model)))
        seconds = time.perf_counter() - start
        print(
            f"  {length:5d} tokens: {seconds * 1e3:9.1f} ms  "
            f"({seconds / length * 1e3:6.1f} ms/token)"
        )


if __name__ == "__main__":
    main()
