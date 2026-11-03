#!/bin/bash
# publish-tree.sh keeps the newest two versions of each package in a directory and drops older ones, never a
# package the run itself placed; each Fedora release gets its own tree. Needs a Fedora container with rpm-build,
# createrepo_c, python3-rpm and findutils.
#
#   tests/channel-prune-rpm.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
pub=$here/.github/actions/publish-rpms/publish-tree.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

build() { # <version> <fedora>
    rm -rf top in && mkdir -p top/SPECS in
    cat > top/SPECS/demo.spec <<SPEC
Name: demo
Version: $1
Release: 1%{?dist}
Summary: A demo for the channel
License: GPL-3.0-or-later
BuildArch: noarch
%description
A demo.
%files
%changelog
* Wed Nov 04 2026 Pau Aliagas <linuxnow@gmail.com> - $1-1
- Version $1.
SPEC
    rpmbuild --define "_topdir $work/top" --define "dist .fc$2" -bb top/SPECS/demo.spec >/dev/null
    cp top/RPMS/noarch/*.rpm in/
}
have() { [ -f "tree/fedora/$2/noarch/demo-$1-1.fc$2.noarch.rpm" ]; }
fail() { echo "FAIL: $*" >&2; exit 1; }

for v in 1.0.0 1.1.0 1.10.0; do build "$v" 44; "$pub" tree in >/dev/null; done
have 1.10.0 44 && have 1.1.0 44 || fail "the two newest versions are not both kept"
have 1.0.0 44 && fail "1.0.0 is still in the channel after two newer versions"

# a package this run places stays even when it is older than both kept ones
build 1.0.5 44; out=$("$pub" tree in)
have 1.0.5 44 || fail "the run removed the package it had just placed"
grep -q '^pruned' <<<"$out" && fail "a run that placed an older version pruned something: $out"

# OMX_CHANNEL_KEEP=1 keeps one; a later publish of another release does not touch fedora/44
build 1.11.0 44; OMX_CHANNEL_KEEP=1 "$pub" tree in >/dev/null
[ "$(find tree/fedora/44/noarch -name 'demo-*.rpm' | wc -l)" = 1 ] && have 1.11.0 44 || fail "OMX_CHANNEL_KEEP=1 did not leave only the newest"
build 1.11.0 45; "$pub" tree in >/dev/null
have 1.11.0 45 && have 1.11.0 44 || fail "the fc45 build is not filed beside fc44"
test -f tree/fedora/45/noarch/repodata/repomd.xml || fail "fedora/45 has no metadata"

OMX_CHANNEL_KEEP=0 "$pub" tree in >/dev/null 2>&1 && fail "OMX_CHANNEL_KEEP=0 was accepted"
echo "ok   the channel keeps the two newest versions per package, never prunes what a run placed, files fc45 apart"
