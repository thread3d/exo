set -u
cd ~/projects/Exo/exo || exit 1
echo "########## README 180-320 ##########"
git show origin/main:README.md | sed -n '180,320p'
echo "########## pyproject extras (60-130) ##########"
git show origin/main:pyproject.toml | sed -n '60,130p'
echo "########## existing tooling elsewhere ##########"
for p in ~/.cargo/bin/cargo ~/.cargo/bin/rustc ~/.local/bin/uv ~/.local/bin/node ~/.nvm/versions/node/*/bin/node ~/.volta/bin/node /usr/local/bin/node /usr/local/bin/uv /usr/local/bin/cargo /usr/local/bin/rustc; do [ -e "$p" ] && echo "FOUND $p"; done
ls /usr/local/Cellar /opt/homebrew 2>/dev/null | head
echo "--- os ---"; sw_vers; echo "--- cpu ---"; sysctl -n machdep.cpu.brand_string 2>/dev/null; echo "--- mem ---"; sysctl -n hw.memsize
