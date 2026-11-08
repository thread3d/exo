"""pytest configuration for the exo test suite.

Two things in this tree do not behave the way pytest expects, and both stop a run on a
non-Apple-Silicon machine before a single test executes:

  * ``exo/inference/test_inference_engine.py`` is a script rather than a pytest module.  It runs
    its checks at import time and the CI invokes it as
    ``python -m exo.inference.test_inference_engine``; collecting it would run those checks during
    collection and then fail on the parameter names pytest reads as fixtures.
  * the MLX test modules import ``mlx``, which only exists on Apple Silicon.  pytest treats a
    missing import as a collection error, which aborts the whole run rather than skipping these.

Neither is silenced when the dependency is present, so macOS keeps the coverage it had.
"""

import importlib.util

collect_ignore = ["exo/inference/test_inference_engine.py"]

if importlib.util.find_spec("mlx") is None:
  collect_ignore += [
    "exo/inference/mlx/test_non_blocking.py",
    "exo/inference/mlx/test_sharded_model.py",
  ]
