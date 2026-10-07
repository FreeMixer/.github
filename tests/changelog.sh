#!/bin/bash
# changelog.sh against a throwaway repository: what it generates, and each way it refuses.
#
#   tests/changelog.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
tool=$here/.github/actions/changelog/changelog.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir -p packaging debian

cat > CHANGELOG.md <<'MD'
# Changelog

Older notes are free text.

## 1.2.0 - 2026-10-07

- Faster start, and the 100% CPU spike on a long session is gone. This bullet is long enough that it has to be wrapped for the Debian changelog, which keeps lines short.
- Second thing, written
  over two lines.

## 1.1.0-2 - 2026-09-30

- Fixed a crackle on the monitor output.

## 1.1.0 - 2026-09-01

- First package.

## 2026-07-04

Not a version, ignored.
MD
cat > packaging/demo.spec <<'SPEC'
Name: demo
Version: 1.2.0
Release: 1%{?dist}
Summary: A demo

%description
Demo.

%changelog
* Mon Jan 01 2001 Somebody <s@example.org> - 0.0.1-1
- hand written
SPEC
printf 'Source: demo\nSection: sound\n\nPackage: demo\nArchitecture: any\nDescription: a demo\n x\n' > debian/control
echo "stale" > debian/changelog

expect_fail() {
    local why=$1; shift
    if "$@" >/dev/null 2>"$work/err"; then echo "FAIL: accepted: $why" >&2; exit 1; fi
    grep -q "$why" "$work/err" || { echo "FAIL: refused, but not for '$why':" >&2; cat "$work/err" >&2; exit 1; }
    echo "ok   refused: $why"
}
expect_ok() { "$@" >/dev/null || { echo "FAIL: $*" >&2; exit 1; }; echo "ok   $*" | sed "s|$tool|changelog.sh|"; }

expect_fail 'not what CHANGELOG.md generates' "$tool" check
"$tool" sync
expect_ok "$tool" check
expect_ok "$tool" check -t v1.2.0

grep -q '^\* Wed Oct 07 2026 Pau Aliagas <linuxnow@gmail.com> - 1.2.0-1$' packaging/demo.spec
grep -q '^\* Wed Sep 30 2026 .* - 1.1.0-2$' packaging/demo.spec
grep -q '100%% CPU' packaging/demo.spec
grep -q '^demo (1.2.0) unstable; urgency=medium$' debian/changelog
grep -q '^ -- Pau Aliagas <linuxnow@gmail.com>  Wed, 07 Oct 2026 12:00:00 +0000$' debian/changelog
! grep -q 'hand written' packaging/demo.spec
! awk 'length($0) > 80' debian/changelog | grep -q .
dpkg-parsechangelog -l debian/changelog -S Version 2>/dev/null | grep -qx 1.2.0 || ! command -v dpkg-parsechangelog >/dev/null
echo "ok   the generated files read as intended"

notes=$("$tool" notes 1.2.0)
grep -q '^- Second thing, written over two lines\.$' <<<"$notes"
! grep -q 'First package' <<<"$notes"
echo "ok   release notes of one version"

expect_fail 'no entry for 9.9.9' "$tool" notes 9.9.9
expect_fail 'newest CHANGELOG.md entry is 1.2.0' "$tool" check -t v1.3.0
expect_fail 'newest CHANGELOG.md entry is 1.2.0' "$tool" check -t v1.1.0

sed -i 's/^- hand.*//; s/- Fixed a crackle/- Fixed a crack/' packaging/demo.spec
expect_fail 'not what CHANGELOG.md generates' "$tool" check
"$tool" sync
echo "- sneaked in" >> debian/changelog
expect_fail 'debian/changelog is not what' "$tool" check
"$tool" sync
sed -i 's/^Version: 1.2.0/Version: 1.1.0/' packaging/demo.spec
expect_fail 'says Version 1.1.0' "$tool" check
sed -i 's/^Version: 1.1.0/Version: 1.2.0/; s/^Release: 1/Release: 3/' packaging/demo.spec
expect_fail 'says Release 3' "$tool" check
"$tool" sync
sed -i 's/^Release: 3/Release: 1/' packaging/demo.spec

cp CHANGELOG.md keep.md
sed -i 's/^## 1.1.0-2 - 2026-09-30/## 1.1.0-2 - 2026-11-30/' CHANGELOG.md
expect_fail 'dated after' "$tool" check
cp keep.md CHANGELOG.md
sed -i 's/^## 1.1.0 - 2026-09-01/## 1.2.0 - 2026-09-01/' CHANGELOG.md
expect_fail 'listed twice' "$tool" check
cp keep.md CHANGELOG.md
sed -i 's/^## 1.1.0 - 2026-09-01/## 1.0.0 2026-09-01/' CHANGELOG.md
expect_fail 'malformed heading' "$tool" check
cp keep.md CHANGELOG.md
rm CHANGELOG.md
expect_fail 'no CHANGELOG.md' "$tool" check
echo "changelog tests: all passed"
