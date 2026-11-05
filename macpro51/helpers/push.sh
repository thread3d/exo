#!/bin/bash
# Push the named files (repo-relative) from the local ./repo working copy to macpro51:~/projects/Strata/Strata/
# preserving their directory structure.  Run from anywhere:  ./push.sh metal/src/mtl_rt.mm ...
set -e
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/repo"
args=()
for p in "$@"; do
  p="${p#repo/}"
  p="/${p#./}"
  args+=("./$p")
done
rsync -aR -e "ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $HOME/.ssh/id_ed25519" \
  "${args[@]}" threaded@192.168.0.118:'projects/Strata/Strata/'
