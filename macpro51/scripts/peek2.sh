set -u
cd ~/projects/Exo/exo || exit 1
show(){ echo "########## $1 ##########"; git show "origin/main:$1" 2>&1 | sed -n "${2:-1,200p}"; echo; }
show .python-version 1,10
show PLATFORMS.md 1,80
show pyproject.toml 1,80
show justfile 1,60
echo "########## README: from source ##########"
git show origin/main:README.md | sed -n '/[Ff]rom source/,/^## /p' | head -80
