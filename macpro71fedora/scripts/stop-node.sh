#!/usr/bin/env bash
# Stop the node started by start-node.sh, identified by this checkout's path so a node from
# another checkout on the same machine is left alone. The node ends its own runner processes.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pattern="$(printf '%s/.venv/bin/exo$' "$REPO_ROOT")"
pkill -f "$pattern" 2>/dev/null
sleep 2
exit 0
