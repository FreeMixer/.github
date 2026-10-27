#!/bin/bash
# The install-clean step retries dnf: a mirror error on the first attempts is survived, a real error fails the third
# attempt and nothing else is retried past it. The step is read out of the action file itself and run with a dnf that
# fails on cue.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
python3 -I - "$here/.github/actions/install-clean/action.yml" "$tmp/step.sh" <<'PY'
import sys
t = open(sys.argv[1]).read()
body = t.split("      run: |\n", 1)[1]
open(sys.argv[2], "w").write("".join(l[8:] if l.startswith("        ") else l for l in body.splitlines(True)))
PY
mkdir -p "$tmp/bin" "$tmp/pkgs"
touch "$tmp/pkgs/a.rpm"
cat > "$tmp/bin/dnf" <<'SH'
#!/bin/bash
n=$(cat "$COUNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$COUNT"
echo "dnf attempt $n: $*"
[ "$n" -gt "$FAILS" ]
SH
cat > "$tmp/bin/rpm" <<'SH'
#!/bin/bash
echo 44
SH
printf '#!/bin/bash\nexit 0\n' > "$tmp/bin/mount"
chmod +x "$tmp/bin/"*
run() { # failures-before-success
  echo 0 > "$tmp/count"
  PATH=$tmp/bin:$PATH COUNT=$tmp/count FAILS=$1 RPMS="$tmp/pkgs/a.rpm" PACKAGES= ROOT=$tmp/root INSTALL_RETRY_SLEEP=0 \
    bash "$tmp/step.sh" >"$tmp/log" 2>&1
}
run 0 || { echo "FAIL: a clean install failed"; exit 1; }
[ "$(cat "$tmp/count")" = 1 ] || { echo "FAIL: a clean install ran dnf more than once"; exit 1; }
run 2 || { echo "FAIL: two mirror errors were not survived"; cat "$tmp/log"; exit 1; }
[ "$(cat "$tmp/count")" = 3 ] || { echo "FAIL: the third attempt was not the one that passed"; exit 1; }
if run 3; then echo "FAIL: a real error passed"; exit 1; fi
[ "$(cat "$tmp/count")" = 3 ] || { echo "FAIL: a failing install was tried $(cat "$tmp/count") times, three expected"; exit 1; }
grep -q 'dnf attempt 3' "$tmp/log" || { echo "FAIL: the last attempt's output is not on the log"; exit 1; }
grep -q -- '--setopt=retries=5' "$tmp/log" || { echo "FAIL: dnf runs without retries=5"; exit 1; }
echo "ok   install-clean retries dnf three times on a non-zero exit, prints every attempt and fails on the third"
