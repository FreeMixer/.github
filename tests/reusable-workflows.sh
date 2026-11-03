#!/bin/bash
# The reusable workflows: each is callable (workflow_call), names every input it reads, and calls this repository's
# actions and workflows at v1, never at a branch; the no-local-copies check proves itself. A job whose runner comes
# from the caller's runs-on input falls back to a GitHub-hosted runner for a pull request from a fork, whatever the
# caller passed, so fork pull requests never reach a self-hosted runner.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
fail=0
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
cat > "$t/check.py" <<'PY'
import re, sys, yaml
f = sys.argv[1]; text = open(f).read(); d = yaml.safe_load(text)
on = d.get(True) or d.get("on")
assert isinstance(on, dict) and "workflow_call" in on, f"{f}: not callable"
declared = set(((on["workflow_call"] or {}).get("inputs") or {}).keys())
used = set(re.findall(r"inputs\.([a-z0-9-]+)", text))
assert used <= declared, f"{f}: reads undeclared inputs {sorted(used - declared)}"
for ref in re.findall(r"uses: (FreeMixer/\.github/\S+)", text):
    assert ref.endswith("@v1"), f"{f}: {ref} is not called at v1"
guard = ("${{ startsWith(github.event_name, 'pull_request') && github.event.pull_request.head.repo.full_name != "
         "github.repository && 'ubuntu-latest' || inputs.runs-on }}")
for name, job in (d.get("jobs") or {}).items():
    ro = str(job.get("runs-on", ""))
    assert "inputs.runs-on" not in ro or ro == guard, \
        f"{f}: job {name} takes the caller's runs-on without the fork fallback: {ro}"
print(f"ok   {f.split('/')[-1]}")
PY
check() { python3 -I "$t/check.py" "$1"; }

for w in public-sources-check ci-node ci-c fuzz release-c-lib release-npm; do
  check "$here/.github/workflows/$w.yml" || fail=1
done
"$here/.github/actions/no-local-copies/check.sh" --self-test >/dev/null || { echo "FAIL no-local-copies self-test"; fail=1; }

# sabotage: an input read but not declared is caught
sed 's/\${{ inputs.commands }}/${{ inputs.undeclared }}/' "$here/.github/workflows/ci-c.yml" > "$t/ci-c.yml"
if check "$t/ci-c.yml" >/dev/null 2>&1; then echo "FAIL sabotage: an undeclared input passes"; fail=1
else echo "ok   sabotage: an undeclared input is red"; fi

# sabotage: a runs-on taken straight from the input, without the fork fallback, is caught
for w in ci-node ci-c fuzz; do
  sed -E 's/^( +runs-on: ).*inputs\.runs-on \}\}$/\1${{ inputs.runs-on }}/' "$here/.github/workflows/$w.yml" > "$t/$w.yml"
  if cmp -s "$here/.github/workflows/$w.yml" "$t/$w.yml"; then
    echo "FAIL sabotage: $w.yml has no fork fallback to strip"; fail=1
  elif check "$t/$w.yml" >/dev/null 2>&1; then
    echo "FAIL sabotage: $w.yml without the fork fallback passes"; fail=1
  else echo "ok   sabotage: $w.yml without the fork fallback is red"; fi
done
exit "$fail"
