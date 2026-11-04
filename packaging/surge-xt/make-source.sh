#!/bin/bash
# Lay out Surge XT's source as the spec and the DEB build it: the upstream commit .github/pins.txt names, with every
# submodule at the commit that commit records (a GitHub archive of the repository holds none of them, and Surge
# does not build without JUCE, the CLAP wrapper and the sst libraries).
#
#   make-source.sh <dir>                      the checkout, with its .git directories, for the DEB build
#   make-source.sh <dir> <tarball>            the same without .git, as the tarball the spec's Source0 names
#
# The tarball is reproducible: sorted names, owner 0, the commit's time as mtime. Needs git and tar.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
read -r _ url pin < <(grep '^surge-xt ' "$here/../../.github/pins.txt") || { echo "surge-xt has no line in pins.txt" >&2; exit 1; }
dir=$(readlink -m "${1:?usage: make-source.sh <dir> [<tarball>]}")

retry() {
    local attempt
    for attempt in 1 2 3 4 5; do
        "$@" && return 0
        [ "$attempt" = 5 ] && return 1
        sleep $((attempt * 3))
    done
}

mkdir -p "$dir"
git -C "$dir" init -q
retry git -C "$dir" fetch -q --depth 1 "$url" "$pin"
git -C "$dir" checkout -q FETCH_HEAD
[ "$(git -C "$dir" rev-parse HEAD)" = "$pin" ] || { echo "surge is not at $pin" >&2; exit 1; }
retry git -C "$dir" submodule update --init --recursive --depth 1 --jobs 4

if [ -n "${2:-}" ]; then
    tarball=$(readlink -m "$2")
    when=$(git -C "$dir" log -1 --format=%ct)
    find "$dir" -name .git -prune -exec rm -rf {} +
    parent=$(dirname "$dir")
    base=$(basename "$dir")
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$when" \
        --transform "s,^$base,surge-xt-$pin," -C "$parent" -czf "$tarball" "$base"
fi
