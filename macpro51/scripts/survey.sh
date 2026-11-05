set -u
cd ~/projects/Exo/exo || exit 1
echo "=== HOME ==="; echo "$HOME"
echo "=== pythons ==="
for p in /usr/bin/python3 /usr/local/bin/python3.1{0,1,2,3,4,5} /opt/homebrew/bin/python3 ~/.local/bin/python3 ~/.pyenv/shims/python3 ~/miniconda3/bin/python3 ~/anaconda3/bin/python3; do
  [ -x "$p" ] && printf "%-45s %s\n" "$p" "$("$p" -V 2>&1)"
done
echo "=== existing venvs / env dirs in project ==="
ls -d .venv venv env .conda 2>/dev/null
echo "=== is exo installed? ==="
/usr/bin/python3 -m pip list 2>/dev/null | grep -i -e exo -e tinygrad -e mlx | head
echo "=== xcode clt / compilers ==="
xcode-select -p 2>&1; command -v cc clang make cmake ninja node npm cargo rustc go 2>/dev/null
echo "=== disk ==="
df -h ~ | tail -1
echo "=== README build section ==="
grep -n -i -A4 -e "^## Install" -e "pip install" -e "python -m" README.md | head -40
echo "=== install.sh ==="
cat install.sh
