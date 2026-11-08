#!/usr/bin/env bash
#
# Build exo into ./.venv and install it in editable mode.
#
#   ./install.sh             build and install, then tell you how to start exo
#   source install.sh        build, install, and leave ./.venv activated
#
# exo needs Python >= 3.12 (see README.md).  Some otherwise well supported
# systems -- notably Ubuntu 20.04 on the NVIDIA Jetson -- ship an older
# interpreter and no working `python3 -m venv` at all, so this script looks for
# a usable interpreter instead of assuming one, checks any existing .venv
# before trusting it, and stops with an actionable message rather than leaving
# a half-installed tree behind.
#
# Set PYTHON=/path/to/python to choose the interpreter explicitly.

# `source install.sh` must not close the caller's shell or leak shell options
# into it, so the work runs inside a function, failures only return, and
# nothing is set on the caller's shell by accident.
_install_sourced=0
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
  _install_sourced=1
fi

_install_fail() {
  printf 'install.sh: %s\n' "$*" >&2
}

# Print the interpreter's absolute path if it is recent enough and able to
# create a virtual environment with pip in it.
_install_usable_python() {
  local exe="$1"
  [ -n "$exe" ] || return 1
  command -v "$exe" >/dev/null 2>&1 || return 1
  exe="$(command -v "$exe")"
  [ -x "$exe" ] || return 1
  # Version gate.  Fed as a script so this stays readable on any interpreter.
  "$exe" - 3 12 >/dev/null 2>&1 <<'PY' || return 1
import sys
raise SystemExit(0 if sys.version_info[:2] >= (int(sys.argv[1]), int(sys.argv[2])) else 1)
PY
  # `ensurepip` is what `python -m venv` needs to put pip in the environment.
  # Debian and Ubuntu split it into a separate package, so a recent interpreter
  # can still be unable to build a venv.
  "$exe" -c 'import ensurepip' >/dev/null 2>&1 || return 1
  printf '%s\n' "$exe"
}

# Find a usable interpreter: an explicit choice first, then the newest on PATH,
# then the places a standalone / conda / pyenv install hides.
_install_find_python() {
  local candidate
  if [ -n "${PYTHON:-}" ]; then
    candidate="$(_install_usable_python "$PYTHON")" && { printf '%s\n' "$candidate"; return 0; }
    _install_fail "PYTHON=$PYTHON is not a Python >= 3.12 with a working venv module"
    return 1
  fi

  local paths
  paths="$(ls -d "$HOME"/miniconda3/bin/python3 "$HOME"/anaconda3/bin/python3 \
                 "$HOME"/miniforge3/bin/python3 "$HOME"/.pyenv/versions/*/bin/python3 \
                 /opt/python3*/bin/python3 /usr/local/bin/python3 2>/dev/null || true)"

  for candidate in python3.14 python3.13 python3.12 $paths python3; do
    if candidate="$(_install_usable_python "$candidate")"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# An existing .venv is only reused when it is genuinely usable.  A venv that was
# moved or copied keeps the absolute shebangs of its old location, so every
# console script in it -- pip included -- dies with "bad interpreter"; the
# interpreter itself still works when driven as a module, which is exactly why
# this has to run a script and not just the interpreter.
_install_venv_healthy() {
  local venv="$1" py="$1/bin/python"
  [ -f "$venv/pyvenv.cfg" ] || return 1
  [ -x "$py" ] || return 1
  _install_usable_python "$py" >/dev/null || return 1
  "$venv/bin/pip" --version >/dev/null 2>&1 || return 1
  "$py" -c 'import sys; raise SystemExit(0 if sys.prefix != sys.base_prefix else 1)' >/dev/null 2>&1 || return 1
  return 0
}

_install_run() {
  local venv=".venv" base_py

  if _install_venv_healthy "$venv"; then
    printf 'Reusing the existing %s (%s)\n' "$venv" "$("$venv/bin/python" --version 2>&1)"
  else
    if [ -e "$venv" ]; then
      printf 'Existing %s is not usable (moved from another path, or built by a different Python); recreating it.\n' "$venv" >&2
      rm -rf "$venv" || { _install_fail "could not remove the old $venv"; return 1; }
    fi
    base_py="$(_install_find_python)" || {
      if [ -z "${PYTHON:-}" ]; then
        _install_fail "no Python >= 3.12 with a working venv module was found.
Install one and re-run, for example:
  Ubuntu/Debian:  sudo apt install python3.12 python3.12-venv
  pyenv:          pyenv install 3.12 && pyenv global 3.12
  conda:          conda create -n exo python=3.12 && conda activate exo
or point this script at one:  PYTHON=/path/to/python3.12 ./install.sh"
      fi
      return 1
    }
    printf 'Creating %s with %s (%s)\n' "$venv" "$base_py" "$("$base_py" --version 2>&1)"
    "$base_py" -m venv "$venv" || { _install_fail "could not create $venv"; return 1; }
  fi

  # Always drive pip through the venv's interpreter: `python -m pip` cannot be
  # broken by a stale shebang the way the `pip` script can.
  "$venv/bin/python" -m pip install -e . || { _install_fail "pip install -e . failed"; return 1; }
  return 0
}

if _install_run; then
  if [ "$_install_sourced" = 1 ]; then
    # shellcheck disable=SC1091
    . .venv/bin/activate
    printf '\nexo is installed and .venv is active. Start it with: exo\n'
  else
    printf '\nexo is installed in .venv. Start it with:\n\n  source .venv/bin/activate && exo\n\n'
  fi
  _install_rc=0
else
  _install_rc=1
fi

unset -f _install_fail _install_usable_python _install_find_python _install_venv_healthy _install_run

if [ "$_install_rc" != 0 ]; then
  if [ "$_install_sourced" = 1 ]; then
    unset _install_rc _install_sourced
    return 1
  fi
  unset _install_rc _install_sourced
  exit 1
fi
unset _install_rc _install_sourced
