set -u
cd ~/projects/Exo/exo || exit 1
echo "########## README build-from-source region ##########"
git show origin/main:README.md | awk '/[Bb]uild|[Rr]un from source|uv sync|just /{print NR": "$0}' | head -60
echo
echo "########## .python-version ##########"
git show origin/main:.python-version
echo "########## pyproject [project] section ##########"
git show origin/main:pyproject.toml | sed -n '1,60p'
echo "########## justfile ##########"
git show origin/main:justfile | head -60
