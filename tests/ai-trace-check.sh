#!/bin/bash
# The ai-trace-check action: the checker reads a range, refuses an attributed commit, passes a clean one, and a
# checker without its patterns is not a pass. With OPS_DIR set, the shipped copy must equal the ops list.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
act=$here/.github/actions/ai-trace-check
chk=$act/ai-trace-commit-check.sh
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

"$chk" --selftest | grep -q '^selftest: GREEN' || fail "selftest not green"

cd "$tmp"; git init -q r; cd r
git config user.email t@example.invalid; git config user.name t; git config commit.gpgsign false
git commit -q --allow-empty -m base; git branch -M main; git checkout -q -b topic
git commit -q --allow-empty -m "clean change"
"$chk" main..HEAD >/dev/null || fail "a clean commit was refused"
git commit -q --allow-empty -m "change" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
if "$chk" main..HEAD >/dev/null; then fail "an attributed commit passed"; fi

# sabotage: the same commit against an empty pattern list must not read as a hit, and a missing list is exit 2
echo '{"markers": []}' > "$tmp/empty.json"
AI_TRACE_PATTERNS="$tmp/empty.json" "$chk" main..HEAD >/dev/null || fail "sabotage setup: empty list should find nothing"
echo "sabotage: the empty list is blind, as the selftest expects"
rc=0; AI_TRACE_PATTERNS="$tmp/none.json" "$chk" main..HEAD >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a missing pattern list gave $rc, not 2"

if [ -n "${OPS_DIR:-}" ]; then
  for f in ai-trace-commit-check.sh ai-trace-patterns.json; do
    cmp -s "$act/$f" "$OPS_DIR/$f" || fail "$f differs from $OPS_DIR/$f (run tools/sync-ai-trace.sh)"
  done
fi
echo "ai-trace-check: ok"
