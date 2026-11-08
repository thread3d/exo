"""A CPU-only MLX backend computes in float32, and says so once.

MLX emulates float16 arithmetic on machines without native float16 - its x86 CPU kernels do it
in scalar code - and every model card loads with float16 activations, so on a CPU the ops that
aren't quantized matmuls all take the slow path. Measured on a Xeon W-3275, float16 elementwise
moved 0.7 GB/s against 22 GB/s for float32, and casting a 4-bit 0.6B model took decode from
3559 ms/token to 441.
"""

import mlx.core as mx
import pytest
from loguru import logger

from exo.worker.engines.mlx.utils_mlx import CPU_DTYPE_ENV, cpu_compute_dtype


class _LoggerSpy:
    """Records the warnings a test expects, without the runner's logging setup."""

    def __init__(self) -> None:
        self.warnings: list[str] = []

    def warning(self, message: str) -> None:
        self.warnings.append(message)


@pytest.fixture
def cpu_device(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(mx, "default_device", lambda: mx.cpu)


@pytest.fixture
def gpu_device(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(mx, "default_device", lambda: mx.gpu)


@pytest.fixture
def logged(monkeypatch: pytest.MonkeyPatch) -> _LoggerSpy:
    spy = _LoggerSpy()
    monkeypatch.setattr(logger, "warning", spy.warning)
    return spy


def test_cpu_computes_in_float32(
    cpu_device: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(CPU_DTYPE_ENV, raising=False)
    assert cpu_compute_dtype() == mx.float32


def test_a_gpu_keeps_the_checkpoint_dtype(
    gpu_device: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A GPU has real float16, so widening there would only cost memory and bandwidth."""
    monkeypatch.delenv(CPU_DTYPE_ENV, raising=False)
    assert cpu_compute_dtype() is None


def test_the_environment_overrides_the_choice(
    cpu_device: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(CPU_DTYPE_ENV, "bf16")
    assert cpu_compute_dtype() == mx.bfloat16
    monkeypatch.setenv(CPU_DTYPE_ENV, "float16")
    assert cpu_compute_dtype() == mx.float16


def test_the_environment_can_ask_for_the_checkpoint_dtype(
    gpu_device: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(CPU_DTYPE_ENV, "float32")
    assert cpu_compute_dtype() == mx.float32


def test_an_unknown_override_warns_and_falls_back(
    cpu_device: None, monkeypatch: pytest.MonkeyPatch, logged: _LoggerSpy
) -> None:
    monkeypatch.setenv(CPU_DTYPE_ENV, "float64")
    assert cpu_compute_dtype() == mx.float32
    assert any("float64" in warning for warning in logged.warnings)
