#!/bin/bash
# A source package handed to publish-tree.sh lands in fedora/<release>/SRPMS/ next to the binaries' tree, a second
# publish keeps it, and its directory gets metadata. Needs a Fedora container with rpm-build, createrepo_c,
# python3-rpm and dnf.
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
