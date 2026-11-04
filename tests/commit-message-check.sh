#!/bin/bash
# The commit-message-check action: the checker reads a range, refuses an attributed commit, passes a clean one, and a
# checker without its patterns is not a pass. The list beside the checker is the one list every repository reads.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
act=$here/.github/actions/commit-message-check
chk=$act/commit-message-check.sh
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
COMMIT_MESSAGE_PATTERNS="$tmp/empty.json" "$chk" main..HEAD >/dev/null || fail "sabotage setup: empty list should find nothing"
echo "sabotage: the empty list is blind, as the selftest expects"
rc=0; COMMIT_MESSAGE_PATTERNS="$tmp/none.json" "$chk" main..HEAD >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a missing pattern list gave $rc, not 2"

# the stub every repository copies into .githooks/commit-msg carries the licence lines a repository's own SPDX check
# reads in a file's first lines (2026-11-03: omx-panel's make spdx went red on the copy)
head -4 "$act/commit-msg" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || fail "the stub has no SPDX line"
head -4 "$act/commit-msg" | grep -q '^# Copyright (C) ' || fail "the stub has no copyright line"

# the stub finds its checker: cloned at v1 on first use, fetched at v1 again once its last fetch is stale, and with no
# checker anywhere it refuses the commit and says so (it exited 127, unnamed, before)
stub=$act/commit-msg
git init -q "$tmp/o"; cp -r "$here/.github" "$tmp/o/"
G="git -C $tmp/o -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false -c tag.gpgsign=false"
$G add -A; $G commit -qm one; $G tag v1
git clone -q --bare "$tmp/o" "$tmp/o.git"
mkdir -p "$tmp/home" "$tmp/s/r"; git -C "$tmp/s/r" init -q
echo "clean change" > "$tmp/msg"; printf 'change\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$tmp/bad"
hook() { (cd "$tmp/s/r" && env -u FREEMIXER_DOTGITHUB HOME=$tmp/home FREEMIXER_DOTGITHUB_URL=$1 sh "$stub" "$2"); }
rc=0; out=$(hook "$tmp/none.git" "$tmp/msg" 2>&1) || rc=$?
[ "$rc" = 1 ] || fail "with no checker anywhere the stub gave $rc, not 1"
grep -q 'no commit-message checker at' <<<"$out" || fail "with no checker anywhere the stub did not say why: $out"
[ ! -e "$tmp/home/.cache/omx/freemixer-dotgithub" ] || fail "a failed clone left a cache behind"
hook "$tmp/o.git" "$tmp/msg" >/dev/null 2>&1 || fail "the stub did not clone v1 and pass a clean message"
cache=$tmp/home/.cache/omx/freemixer-dotgithub
[ "$(git -C "$cache" rev-parse HEAD)" = "$(git -C "$tmp/o" rev-parse v1)" ] || fail "the first use did not clone v1"
if hook "$tmp/o.git" "$tmp/bad" >/dev/null 2>&1; then fail "the stub passed an attributed message"; fi
touch "$tmp/o/moved"; $G add -A; $G commit -qm two; $G tag -f v1 >/dev/null; git -C "$tmp/o" push -q --force "$tmp/o.git" refs/tags/v1
touch -d '20 minutes ago' "$cache/.git/FETCH_HEAD"
hook "$tmp/o.git" "$tmp/msg" >/dev/null 2>&1 || fail "the refreshed stub refused a clean message"
[ "$(git -C "$cache" rev-parse HEAD)" = "$(git -C "$tmp/o" rev-parse v1)" ] || fail "a stale cache was not fetched at the moved v1"
mv "$tmp/o.git" "$tmp/o.away"; touch -d '20 minutes ago' "$cache/.git/FETCH_HEAD"
rc=0; hook "$tmp/o.git" "$tmp/msg" >/dev/null 2>"$tmp/err" || rc=$?
[ "$rc" = 0 ] && grep -q 'could not fetch v1' "$tmp/err" || fail "an unreachable remote did not fall back to the cached checker and say so (rc $rc)"

echo "commit-message-check: ok"
