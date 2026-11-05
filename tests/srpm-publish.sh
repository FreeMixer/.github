#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# A source package handed to publish-tree.sh lands in fedora/<release>/SRPMS/ next to the binaries' tree, a second
# publish keeps it, and its directory gets metadata; and record-srpm.sh records every source package a publish
# served, one per Fedora release of the matrix (the mod-host publish of 0.10.9 built fc44 and fc45 and the record
# read the two as one path). Needs a Fedora container with rpm-build, createrepo_c, python3-rpm and dnf.
#
#   tests/srpm-publish.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

mkdir -p top/SPECS rpms
cat > top/SPECS/demo.spec <<'SPEC'
Name: demo
Version: 1.0.0
Release: 1.fmx%{?dist}
Summary: A demo for the channel
License: GPL-3.0-or-later
BuildArch: noarch
%description
A demo.
%files
%changelog
* Wed Sep 30 2026 Pau Aliagas <linuxnow@gmail.com> - 1.0.0-1
- First package.
SPEC
rpmbuild --define "_topdir $work/top" --define 'dist .fc44' -ba top/SPECS/demo.spec >/dev/null
# the layout build.sh leaves: binaries at the top, the source package in SRPMS/
cp top/RPMS/noarch/*.rpm rpms/
mkdir -p rpms/SRPMS && cp top/SRPMS/*.src.rpm rpms/SRPMS/
srpm=$(basename rpms/SRPMS/*.src.rpm)
test "$srpm" = demo-1.0.0-1.fmx.fc44.src.rpm
test "$(rpm -qp --qf '%{SOURCERPM}' rpms/demo-1.0.0-1.fmx.fc44.noarch.rpm)" = "$srpm"

"$here/.github/actions/publish-rpms/publish-tree.sh" tree rpms
test -f "tree/fedora/44/SRPMS/$srpm" || { echo "FAIL: $srpm is not under fedora/44/SRPMS/" >&2; exit 1; }
test -f tree/fedora/44/SRPMS/repodata/repomd.xml || { echo "FAIL: SRPMS/ has no metadata" >&2; exit 1; }
test -f tree/fedora/44/noarch/demo-1.0.0-1.fmx.fc44.noarch.rpm
test "$(find tree -name '*.src.rpm' | wc -l)" = 1 || { echo "FAIL: the source package is filed more than once" >&2; exit 1; }
sum=$(sha256sum "tree/fedora/44/SRPMS/$srpm" | cut -d' ' -f1)

# a second publish of the same NEVRA keeps the file
again=$("$here/.github/actions/publish-rpms/publish-tree.sh" tree rpms)
grep -q "^kept   $srpm" <<<"$again" || { echo "FAIL: the second publish did not keep $srpm" >&2; exit 1; }
test "$(sha256sum "tree/fedora/44/SRPMS/$srpm" | cut -d' ' -f1)" = "$sum"
echo "ok   $srpm filed under fedora/44/SRPMS/ with metadata, kept on a second publish"

# the record of a publish that built two Fedora releases: one line per source package, each with its own sha256
record=$here/.github/actions/publish-rpms/record-srpm.sh
mkdir -p signed top45/SPECS && cp top/SPECS/demo.spec top45/SPECS/
rpmbuild --define "_topdir $work/top45" --define 'dist .fc45' -bs top45/SPECS/demo.spec >/dev/null 2>&1
cp top/SRPMS/*.src.rpm top45/SRPMS/*.src.rpm signed/
test "$(ls signed/*.src.rpm | wc -l)" = 2
out=$("$record" signed demo) || { echo "FAIL: record-srpm.sh is red with two source packages" >&2; exit 1; }
for rel in 44 45; do
    f=demo-1.0.0-1.fmx.fc$rel.src.rpm
    grep -q "^- fedora $rel: https://www.openmixer.org/rpm/fedora/$rel/SRPMS/$f\$" <<<"$out" \
        || { echo "FAIL: the record does not name fedora/$rel/SRPMS/$f" >&2; printf '%s\n' "$out" >&2; exit 1; }
    grep -q "^  sha256: $(sha256sum "signed/$f" | cut -d' ' -f1)\$" <<<"$out" \
        || { echo "FAIL: the record carries another sha256 for $f" >&2; exit 1; }
done
test "$(grep -c '^- fedora' <<<"$out")" = 2
mkdir -p empty
if "$record" empty demo >/dev/null 2>&1; then echo "FAIL: record-srpm.sh is green with no source package" >&2; exit 1; fi
echo "ok   record-srpm.sh records fedora 44 and 45, each with its sha256, and is red with none"
