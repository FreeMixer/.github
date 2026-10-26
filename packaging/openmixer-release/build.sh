#!/bin/bash
# Build openmixer-release, the package that adds the OpenMixer repository, with the key file the channel serves.
#
#   build.sh rpm|deb <key file> <output dir>
#
# The key file is the one the channel serves to the package manager the package is for (rpm/RPM-GPG-KEY-openmixer,
# deb/openmixer.asc), fetched by the caller: the package ships those bytes, so a machine verifies with what the
# channel serves and a key added to the channel reaches it as an update. The RPM's Version-Release and the DEB's
# version are one release: a build where they differ is refused. rpm runs in a Fedora container with rpm-build
# and gnupg2; deb in a Debian one with dpkg-dev, debhelper, lintian and gnupg, as root.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
usage='usage: build.sh rpm|deb <key file> <output dir>'
kind=${1:?$usage}
key=$(readlink -f "${2:?$usage}")
out=$(readlink -m "${3:?$usage}")
spec=$here/openmixer-release.spec

version=$(sed -n 's/^Version: *//p' "$spec")
release=$(sed -n 's/^Release: *\([0-9][0-9.]*\)%{?dist}$/\1/p' "$spec")
[ -n "$version" ] && [ -n "$release" ] || { echo "no Version or Release N%{?dist} in $spec" >&2; exit 1; }
debver=$(sed -n '1s/^openmixer-release (\([^)]*\)).*/\1/p' "$here/debian/changelog")
[ "$debver" = "$version-$release" ] || { echo "debian/changelog says $debver, the spec $version-$release" >&2; exit 1; }

primaries=$(gpg --batch --with-colons --import-options show-only --import < "$key" 2>/dev/null |
    awk -F: '/^pub:/ {p = 1; next} /^fpr:/ && p {print $10; p = 0}')
[ -n "$primaries" ] || { echo "no public key readable from $key" >&2; exit 1; }
echo "openmixer-release $version-$release ($kind) ships $(tr '\n' ' ' <<< "$primaries")"

mkdir -p "$out"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
case "$kind" in
rpm)
    mkdir -p "$work/SOURCES"
    cp "$here/openmixer.repo" "$work/SOURCES/"
    cp "$key" "$work/SOURCES/RPM-GPG-KEY-openmixer"
    rpmbuild --define "_topdir $work" -bb "$spec"
    find "$work/RPMS" -name 'openmixer-release-*.noarch.rpm' -exec cp {} "$out/" \;
    ls "$out"/openmixer-release-*.noarch.rpm
    ;;
deb)
    mkdir -p "$work/src"
    cp -r "$here/debian" "$work/src/debian"
    cp "$key" "$work/src/debian/openmixer-archive-keyring.asc"
    (cd "$work/src" && dpkg-buildpackage -b -uc -us && lintian --fail-on error,warning ../openmixer-release_*.changes)
    cp "$work"/openmixer-release_*_all.deb "$out/"
    ls "$out"/openmixer-release_*_all.deb
    ;;
*)
    echo "$usage" >&2
    exit 2
    ;;
esac
