#!/usr/bin/env bash
# Environment for building and running exo on this machine. Source it from the repo root:
#   . macpro71fedora/scripts/env.sh
#
# What it covers that a normal Linux login does not need:
#   - $HOME is read-only in this sandbox, so every directory a build or a node writes to goes in
#     the workspace instead.
#   - conda's uv on PATH cannot parse /etc/uv/uv.toml, so the system one is used.
#   - cargo would write to ~/.cargo, so CARGO_HOME points at the workspace.
# See STATUS.md, "Build environment", for why each of these exists.

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
export UV="${UV:-/usr/bin/uv}"          # conda's uv rejects /etc/uv/uv.toml's system-certs
export UV_CACHE_HOME="${UV_CACHE_HOME:-$WORK_ROOT/.cache/uv}"
export CARGO_HOME="${CARGO_HOME:-$WORK_ROOT/.cache/cargo}"
export npm_config_cache="${npm_config_cache:-$WORK_ROOT/.cache/npm}"
export LOG_DIR="${LOG_DIR:-$WORK_ROOT/logs}"

# The virtualenv is built from uv's own CPython rather than conda's: conda's interpreter has
# DT_RPATH=$ORIGIN/../lib, which pins libstdc++ to conda's copy (too old for MLX) in any process
# that loads it. PYTHON is the interpreter `uv sync --python` is given.
export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$WORK_ROOT/.cache/pythons}"
export PYTHON="$UV_PYTHON_INSTALL_DIR/cpython-3.13-linux-x86_64-gnu/bin/python3.13"

export PATH="/usr/lib64/ccache:$PATH"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" \
         "$EXO_DEFAULT_MODELS_DIR" "$LOG_DIR" "$UV_PYTHON_INSTALL_DIR"
