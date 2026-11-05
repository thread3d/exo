set -u
cd ~/projects/Exo/exo || exit 1
echo "=== do the LFS-modified paths change upstream? ==="
git -c filter.lfs.required=false diff --name-status HEAD origin/main -- \
  docs/exo-logo-transparent-black-text.png docs/exo-logo-transparent.png docs/exo-rounded.png \
  exo/apputil/baseimages/image1.png exo/apputil/baseimages/image2.png exo/apputil/baseimages/image3.png \
  exo/apputil/baseimages/image4.png extra/dashboard/sounds/gta5_wasted.mp3 extra/dashboard/sounds/pokemon_evolve.mp3
echo "[diff exit=$?]"
echo "=== .gitattributes upstream ==="
git show origin/main:.gitattributes 2>&1
echo "=== tool versions ==="
/usr/local/bin/cargo --version 2>&1; /usr/local/bin/rustc --version 2>&1
/usr/local/bin/brew --version 2>&1 | head -2
/usr/local/bin/brew list --versions node uv git-lfs 2>&1
/usr/local/bin/python3.13 -V
echo "=== PATH ==="; echo "$PATH"
