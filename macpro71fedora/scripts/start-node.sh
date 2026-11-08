#!/usr/bin/env bash
# Start one exo node in the background, logging to $LOG_DIR/exo.log.
# Any extra arguments are passed to `exo` (e.g. -v, --no-downloads, --api-port 52416).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./env.sh
. "$SCRIPT_DIR/env.sh"
. "$SCRIPT_DIR/stop-node.sh" >/dev/null 2>&1

cd "$REPO_ROOT" || exit 1
nohup "$UV" run --no-sync exo "$@" > "$LOG_DIR/exo.log" 2>&1 &
echo "exo started, pid $!, logging to $LOG_DIR/exo.log"
