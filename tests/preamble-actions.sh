#!/bin/bash
# The tag-names-version step script, run the way the action runs it: a matching tag passes, a mismatch fails,
# a branch run never fails, and an empty version is refused. The step is read out of the action file itself.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
act=$here/.github/actions/tag-names-version/action.yml
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
python3 -I - "$act" "$tmp/step.sh" <<'PY'
import sys, re
t = open(sys.argv[1]).read()
body = t.split("      run: |\n", 1)[1]
open(sys.argv[2], "w").write("".join(l[8:] if l.startswith("        ") else l for l in body.splitlines(True)))
PY
run() { # ref_type ref_name version
  : > "$tmp/out"
  GITHUB_OUTPUT=$tmp/out REF_TYPE=$1 REF_NAME=$2 VERSION=$3 VERSION_COMMAND=${4:-} PREFIX=v bash "$tmp/step.sh" >/dev/null 2>&1
}
run tag v1.2.3 1.2.3 || { echo "FAIL: matching tag refused"; exit 1; }
grep -qx 'version=1.2.3' "$tmp/out" || { echo "FAIL: version output"; exit 1; }
run tag v1.2.4 1.2.3 && { echo "FAIL: mismatched tag passed"; exit 1; }
run branch main 1.2.3 || { echo "FAIL: branch run refused"; exit 1; }
run tag v1.2.3 "" && { echo "FAIL: empty version passed"; exit 1; }
run tag v9.9.9 "" 'echo 9.9.9' || { echo "FAIL: version-command"; exit 1; }
echo "preamble-actions: ok"
