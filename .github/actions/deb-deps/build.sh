#!/bin/bash
# Build the Debian build dependencies of the FreeMixer packages from the pins of .github/pins.txt.
#
#   build.sh <output dir> <name>...      name: a first column of pins.txt that has a directory here
#
# Each is fetched at its pinned commit, given the debian/ directory of its name, built binary-only, linted and
# installed, so the next one and the packages that Build-Depend on it find it. Runs as root in a Debian
# container with dpkg-dev, debhelper, build-essential, git and lintian.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
pins=$here/../../pins.txt
out=$(readlink -m "${1:?usage: build.sh <output dir> <name>...}")
shift
mkdir -p "$out"
work=$(mktemp -d)

for name in "$@"; do
    read -r _ url ref < <(grep "^$name " "$pins") || { echo "$name has no line in pins.txt" >&2; exit 1; }
    [ -d "$here/$name" ] || { echo "no debian directory for $name" >&2; exit 1; }
    src=$work/$name
    mkdir -p "$src"
    git -C "$src" init -q
    git -C "$src" fetch -q --depth 1 "$url" "$ref"
    git -C "$src" checkout -q FETCH_HEAD
    [ "$(git -C "$src" rev-parse HEAD)" = "$ref" ] || { echo "$name is not at $ref" >&2; exit 1; }
    cp -r "$here/$name" "$src/debian"
    (cd "$src" && apt-get build-dep -y --no-install-recommends ./ >/dev/null && dpkg-buildpackage -b -uc -us && lintian --fail-on error,warning ../"${name}"_*.changes)
    cp "$work"/*.deb "$out/"
    apt-get install -y --no-install-recommends "$work"/*.deb
    find "$work" -maxdepth 1 -name '*.deb' -delete
done
ls "$out"
