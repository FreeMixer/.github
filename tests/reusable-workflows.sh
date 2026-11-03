#!/bin/bash
# The reusable workflows: each is callable (workflow_call), names every input it reads, and calls this repository's
# actions and workflows at v1, never at a branch; the no-local-copies check proves itself.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
fail=0
for w in public-sources-check ci-node ci-c fuzz release-c-lib release-npm; do
  f=$here/.github/workflows/$w.yml
  python3 -I - "$f" <<'PY' || fail=1
import re, sys, yaml
f = sys.argv[1]; text = open(f).read(); d = yaml.safe_load(text)
on = d.get(True) or d.get("on")
assert isinstance(on, dict) and "workflow_call" in on, f"{f}: not callable"
declared = set(((on["workflow_call"] or {}).get("inputs") or {}).keys())
used = set(re.findall(r"inputs\.([a-z0-9-]+)", text))
assert used <= declared, f"{f}: reads undeclared inputs {sorted(used - declared)}"
for ref in re.findall(r"uses: (FreeMixer/\.github/\S+)", text):
    assert ref.endswith("@v1"), f"{f}: {ref} is not called at v1"
print(f"ok   {f.split('/')[-1]}")
PY
done
"$here/.github/actions/no-local-copies/check.sh" --self-test >/dev/null || { echo "FAIL no-local-copies self-test"; fail=1; }
# sabotage: an input read but not declared is caught
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
sed 's/\${{ inputs.commands }}/${{ inputs.undeclared }}/' "$here/.github/workflows/ci-c.yml" > "$t/ci-c.yml"
if python3 -I -c "
import re,sys,yaml; t=open('$t/ci-c.yml').read(); d=yaml.safe_load(t); on=d.get(True)
sys.exit(0 if set(re.findall(r'inputs\.([a-z0-9-]+)',t)) <= set(on['workflow_call']['inputs']) else 1)"; then
  echo "FAIL sabotage: an undeclared input passes"; fail=1
else echo "ok   sabotage: an undeclared input is red"; fi
exit "$fail"
