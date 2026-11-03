#!/bin/bash
# The Debian half: publish-tree.sh keeps the newest two versions of each package in a suite's architecture and
# drops older ones, never a package the run itself placed. Needs a Debian container with dpkg-dev and apt-utils.
#
#   tests/channel-prune-deb.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
pub=$here/.github/actions/publish-debs/publish-tree.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

build() { # <version>
    rm -rf pkg debs && mkdir -p pkg/DEBIAN debs/trixie
    printf 'Package: demo\nVersion: %s\nArchitecture: all\nMaintainer: Pau Aliagas <linuxnow@gmail.com>\nDescription: A demo for the channel\n' "$1" > pkg/DEBIAN/control
    dpkg-deb --build --root-owner-group pkg "debs/trixie/demo_$1_all.deb" >/dev/null
}
have() { [ -f "tree/debian/trixie/all/demo_$1_all.deb" ]; }
fail() { echo "FAIL: $*" >&2; exit 1; }

for v in 1.0.0 1.1.0 1.10.0; do build "$v"; "$pub" tree debs >/dev/null; done
have 1.10.0 && have 1.1.0 || fail "the two newest versions are not both kept"
have 1.0.0 && fail "1.0.0 is still in the channel after two newer versions"
grep -q '^Version: 1.0.0$' tree/debian/trixie/Packages && fail "the index still lists 1.0.0"

build 1.0.5; out=$("$pub" tree debs)
have 1.0.5 || fail "the run removed the package it had just placed"
grep -q '^pruned' <<<"$out" && fail "a run that placed an older version pruned something: $out"

OMX_CHANNEL_KEEP=0 "$pub" tree debs >/dev/null 2>&1 && fail "OMX_CHANNEL_KEEP=0 was accepted"
echo "ok   the apt channel keeps the two newest versions per package and never prunes what a run placed"
