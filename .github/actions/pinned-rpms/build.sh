#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# Build the RPMs of the third-party libraries the channel packages from a pinned commit (pugl, nanovg), from
# packaging/<name>/<name>.spec, into $1, and install them so the next one and a caller's build find them.
#
#   build.sh <output dir> <name>...
#
# The spec's commit0 must be the commit .github/pins.txt names for it: the pin moves in one place and the build
# refuses a spec left behind. A file of packaging/<name>/overlay/ is a Source of the spec (the DEB lays the same files
# on the source). Runs as root in a Fedora container. SUFFIX is not taken: these specs carry .omx in their Release.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
pins=$here/../../pins.txt
packaging=$here/../../../packaging
out=$(readlink -m "${1:?usage: build.sh <output dir> <name>...}")
shift
mkdir -p "$out/SRPMS"

dnf install -y --setopt=install_weak_deps=False rpm-build rpmdevtools dnf5-plugins gcc curl pkgconf-pkg-config
for name in "$@"; do
    spec=$packaging/$name/$name.spec
    [ -f "$spec" ] || { echo "no spec for $name" >&2; exit 1; }
    read -r _ _ pin < <(grep "^$name " "$pins") || { echo "$name has no line in pins.txt" >&2; exit 1; }
    commit=$(sed -n 's/^%global commit0 *//p' "$spec")
    [ "$commit" = "$pin" ] || { echo "$name.spec builds $commit, pins.txt pins $pin" >&2; exit 1; }
    top=$(mktemp -d)
    mkdir -p "$top/SOURCES" "$top/SPECS"
    cp "$spec" "$top/SPECS/"
    [ -d "$packaging/$name/overlay" ] && cp "$packaging/$name/overlay/"* "$top/SOURCES/"
    spectool -g -C "$top/SOURCES" "$top/SPECS/$name.spec"
    dnf builddep -y --setopt=install_weak_deps=False "$top/SPECS/$name.spec"
    rpmbuild --define "_topdir $top" -ba "$top/SPECS/$name.spec"
    find "$top/RPMS" -name '*.rpm' -exec cp {} "$out/" \;
    find "$top/SRPMS" -name '*.src.rpm' -exec cp {} "$out/SRPMS/" \;
    dnf install -y --setopt=install_weak_deps=False $(find "$top/RPMS" -name '*.rpm' ! -name '*-debug*')
done
ls "$out"
