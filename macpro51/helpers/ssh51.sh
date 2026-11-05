#!/bin/bash
# Helper: run a command on macpro51 (macOS Big Sur) with a broken-safe ssh config
exec ssh -F /dev/null \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -o ConnectTimeout=15 \
  -i "$HOME/.ssh/id_ed25519" \
  threaded@192.168.0.118 "$@"
