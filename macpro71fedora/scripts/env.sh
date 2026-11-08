#!/usr/bin/env bash
# Environment for running exo and its benchmarks on this machine. Source it:
#   . scripts/env.sh
#
# Two things it covers that a normal Linux login does not need:
#   - $HOME is read-only in this sandbox, so every directory exo writes to goes in the workspace.
#   - the virtualenv was built from a conda interpreter, whose DT_RPATH pins libstdc++ to conda's
#     (too old for MLX), so the system copy is preloaded. See STATUS.md, "Build environment".

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT
WORK_ROOT="${WORK_ROOT:-$(dirname "$REPO_ROOT")}"

# Writable state, kept beside the checkout rather than in $HOME
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$WORK_ROOT/.xdg/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$WORK_ROOT/.xdg/data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$WORK_ROOT/.xdg/cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$WORK_ROOT/.xdg/state}"
export EXO_DEFAULT_MODELS_DIR="${EXO_DEFAULT_MODELS_DIR:-$WORK_ROOT/.xdg/data/exo/models}"
export HF_HOME="${HF_HOME:-$WORK_ROOT/.cache/huggingface}"

# Toolchain
export UV_CACHE_HOME="${UV_CACHE_HOME:-$WORK_ROOT/.cache/uv}"
export UV="${UV:-/usr/bin/uv}"          # conda's uv rejects /etc/uv/uv.toml
export LOG_DIR="${LOG_DIR:-$WORK_ROOT/logs}"

# MLX needs libstdc++ >= GLIBCXX_3.4.30; conda's interpreter would otherwise win
export LD_PRELOAD="/usr/lib64/libstdc++.so.6${LD_PRELOAD:+:$LD_PRELOAD}"
export PATH="/usr/lib64/ccache:$PATH"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" \
         "$EXO_DEFAULT_MODELS_DIR" "$LOG_DIR"
