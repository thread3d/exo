set -u
export PATH=/usr/local/bin:$PATH
cd ~/projects/Exo/exo || exit 1
echo "=== Cargo.toml head ==="
head -40 Cargo.toml
echo "=== rust-toolchain? ==="
ls rust-toolchain* 2>/dev/null || echo "none"
echo "=== Cargo.lock edition/rust-version hints ==="
grep -m5 -n 'rust-version' Cargo.lock | head
echo "=== rust/exo_rs ==="
ls rust/exo_rs | head; sed -n '1,40p' rust/exo_rs/Cargo.toml 2>/dev/null
echo "=== dashboard package.json (engines/scripts) ==="
python3 - <<'PY'
import json
d=json.load(open('dashboard/package.json'))
print('name', d.get('name'), 'version', d.get('version'))
print('engines', d.get('engines'))
print('scripts', json.dumps(d.get('scripts',{}), indent=1)[:800])
print('devDep sample', list(d.get('devDependencies',{}).items())[:12])
PY
echo "=== src tree top ==="
ls src; echo "---"; ls src/exo 2>/dev/null | head -20
