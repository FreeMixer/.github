#!/bin/bash
# changelog.sh against a throwaway git repository: the notes, the %changelog entry and debian/changelog it
# makes from commit subjects, and that it never reads a CHANGELOG.md.
#
#   tests/changelog.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
tool=$here/.github/actions/changelog/changelog.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q -b main .
mkdir debian
printf 'demo (1.1.0) unstable; urgency=medium\n\n  * x\n\n -- t <t@t>  Mon, 01 Jan 2024 00:00:00 +0000\n' > debian/changelog
echo CHANGELOG-BAIT > CHANGELOG.md

commit() { echo "$1" >> f; git add f; GIT_COMMITTER_DATE="$2" git commit -q -m "$1" --date "$2"; }
commit "First version of the thing" "2026-09-01T12:00:00Z"
git tag v1.0.0
commit "Faster start, and the 100% CPU spike on a long session is gone, which was a long standing complaint of people" "2026-09-30T12:00:00Z"
commit "Fix the clip latch" "2026-10-01T12:00:00Z"
git checkout -q -b side; commit "side work" "2026-10-02T12:00:00Z"; git checkout -q main
GIT_COMMITTER_DATE="2026-10-03T12:00:00Z" git merge -q --no-ff side -m "Merge side"
git tag v1.1.0

ok() { echo "ok   $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

notes=$("$tool" notes -C . v1.1.0)
[ "$(echo "$notes" | head -n1)" = "- side work" ] || fail "newest first, merge left out: $notes"
echo "$notes" | grep -q '^- Fix the clip latch$' || fail "subject missing"
echo "$notes" | grep -q 'First version' && fail "reached past the previous tag"
echo "$notes" | grep -q 'Merge side' && fail "merge commit listed"
echo "$notes" | grep -q 'CHANGELOG-BAIT' && fail "read CHANGELOG.md"
ok "notes: subjects since v1.0.0, no merges"

first=$("$tool" notes -C . v1.0.0)
[ "$first" = "- First version of the thing" ] || fail "first release: $first"
ok "notes: the first release is its whole history"

rpm=$("$tool" rpm -C . v1.1.0 1.1.0-1)
[ "$(echo "$rpm" | head -n1)" = "* Sat Oct 03 2026 Pau Aliagas <linuxnow@gmail.com> - 1.1.0-1" ] || fail "rpm header: $rpm"
echo "$rpm" | grep -q '100%% CPU' || fail "percent not escaped: $rpm"
ok "rpm: one entry, % escaped"

"$tool" deb -C . v1.1.0
head -n1 debian/changelog | grep -qx 'demo (1.1.0) unstable; urgency=medium' || fail "deb header kept"
tail -n1 debian/changelog | grep -qx ' -- Pau Aliagas <linuxnow@gmail.com>  Sat, 03 Oct 2026 12:00:00 +0000' || fail "deb trailer"
! awk 'length($0) > 80' debian/changelog | grep -q . || fail "deb line too long"
grep -q '^  \* Fix the clip latch$' debian/changelog || fail "deb bullet"
[ "$(grep -c '^ -- ' debian/changelog)" = 1 ] || fail "deb has one entry"
! grep -q 'CHANGELOG-BAIT' debian/changelog || fail "deb read CHANGELOG.md"
ok "deb: top entry rewritten, folded under 80 columns"

"$tool" notes -C . nonesuch 2>/dev/null && fail "unknown ref accepted"
ok "unknown ref refused"
echo "changelog tests: all passed"
