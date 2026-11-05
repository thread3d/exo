#!/bin/bash
# Poll for macpro51 to come back after the GPU-hang/panic reboot cycle.
# Exits 0 as soon as SSH answers, printing recovery state; exits 1 on timeout.
set -u
DEADLINE=$(( $(date +%s) + ${1:-2400} ))
ATTEMPT=0
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  ATTEMPT=$((ATTEMPT+1))
  for TARGET in macpro51.local 192.168.0.118 192.168.0.116; do
    if ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/home/threaded/projects/macpro51/.ssh_known_hosts \
        -o LogLevel=ERROR -o ConnectTimeout=6 -i "$HOME/.ssh/id_ed25519" \
        "threaded@$TARGET" 'echo HOST_UP; hostname; uptime; sw_vers -productVersion' 2>/dev/null; then
      echo "REACHED $TARGET on attempt $ATTEMPT at $(date '+%H:%M:%S')"
      exit 0
    fi
  done
  sleep 20
done
echo "TIMEOUT after $ATTEMPT attempts at $(date '+%H:%M:%S')"
exit 1
