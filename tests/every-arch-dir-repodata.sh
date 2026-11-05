#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# openmixer.repo points dnf at fedora/<release>/$basearch/ AND fedora/<release>/noarch/. A publish that placed only
# an x86_64 package (mod-host 0.10.9 on fc45) left noarch/ absent, and `dnf install` on fedora:45 failed on
# .../fedora/45/noarch/repodata/repomd.xml: 404. Every release the tree holds must carry repodata in noarch/,
# x86_64/, aarch64/ and SRPMS/, empty or not. Needs a Fedora container with rpm-build and createrepo_c.
#
#   tests/every-arch-dir-repodata.sh
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
Summary: A binary demo for the channel
License: GPL-3.0-or-later
%description
A demo.
%files
%changelog
* Wed Sep 30 2026 Pau Aliagas <linuxnow@gmail.com> - 1.0.0-1
- First package.
SPEC
rpmbuild --target x86_64 --define "_topdir $work/top" --define 'dist .fc45' -bb top/SPECS/demo.spec >/dev/null
cp top/RPMS/x86_64/*.rpm rpms/
test "$(ls rpms | wc -l)" = 1

"$here/.github/actions/publish-rpms/publish-tree.sh" tree rpms
test -f tree/fedora/45/x86_64/demo-1.0.0-1.fmx.fc45.x86_64.rpm

# a release already in the channel that a later publish does not touch is completed too
mkdir -p tree/fedora/44/x86_64
cp rpms/*.rpm tree/fedora/44/x86_64/
bad=0
"$here/.github/actions/publish-rpms/publish-tree.sh" tree rpms >/dev/null
for rel in 44 45; do
    for arch in noarch x86_64 aarch64 SRPMS; do
        if [ ! -f "tree/fedora/$rel/$arch/repodata/repomd.xml" ]; then
            echo "FAIL: fedora/$rel/$arch has no repodata/repomd.xml" >&2; bad=1
        fi
    done
done
[ "$bad" = 0 ] || exit 1
echo "ok   every arch directory of fedora 44 and 45 carries repodata, noarch included"
