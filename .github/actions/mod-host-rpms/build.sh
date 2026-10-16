#!/bin/bash
# Build the mod-host RPMs, with mod-host-protocol and mod-host-protocol-devel, from packaging/mod-host of this
# repository into $1: the audinux spec with the upstream pull requests it carries, until audinux ships them.
# Runs as root in a Fedora container. RELEASE, when set, replaces the spec's Release (the dist tag is kept).
# SUFFIX, when set, is appended to the Release after a dot and before the dist tag, so the channel's package reads
# 11.1.fmx.fc44 (docs/mod-host-carried-patches.md says why it sorts below the audinux build of the same patches).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
carried=$here/../../../packaging/mod-host
out=$(readlink -f "${1:?usage: build.sh <output dir>}")
top=$(mktemp -d)
mkdir -p "$top/SOURCES" "$top/SPECS" "$out"

cp "$carried/mod-host.spec" "$top/SPECS/"
for f in mod-host.service $(sed -n 's/^Patch[0-9]*: *//p' "$carried/mod-host.spec"); do
    cp "$carried/$f" "$top/SOURCES/"
done
if [ -n "${RELEASE:-}" ]; then
    sed -i "s/^Release:.*/Release: $RELEASE%{?dist}/" "$top/SPECS/mod-host.spec"
    grep -qxF "Release: $RELEASE%{?dist}" "$top/SPECS/mod-host.spec" || { echo "Release not set to $RELEASE" >&2; exit 1; }
fi

if [ -n "${SUFFIX:-}" ]; then
    rel=$(sed -n 's/^Release: *\(.*\)%{?dist}.*/\1/p' "$top/SPECS/mod-host.spec")
    [ -n "$rel" ] || { echo "no Release in the spec to suffix" >&2; exit 1; }
    sed -i "s/^Release:.*/Release: $rel.$SUFFIX%{?dist}/" "$top/SPECS/mod-host.spec"
    grep -qxF "Release: $rel.$SUFFIX%{?dist}" "$top/SPECS/mod-host.spec" || { echo "Release not suffixed with $SUFFIX" >&2; exit 1; }
fi

# pipewire's jack first: the builddep would pull jack-audio-connection-kit-devel, which conflicts with it
dnf install -y --setopt=install_weak_deps=False rpm-build rpmdevtools dnf5-plugins gcc make patch curl pkgconf-pkg-config \
    pipewire-jack-audio-connection-kit-devel
spectool -g -C "$top/SOURCES" "$top/SPECS/mod-host.spec"
dnf builddep -y --setopt=install_weak_deps=False "$top/SPECS/mod-host.spec"
rpmbuild --define "_topdir $top" -bb "$top/SPECS/mod-host.spec"

find "$top/RPMS" -name '*.rpm' -exec cp {} "$out/" \;
ls "$out"/mod-host-[0-9]*.rpm "$out"/mod-host-protocol-[0-9]*.rpm "$out"/mod-host-protocol-devel-*.rpm
