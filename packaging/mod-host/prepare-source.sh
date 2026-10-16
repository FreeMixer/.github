#!/bin/bash
# Lay out mod-host's source the way mod-host.spec builds it: the upstream commit the spec names, with the spec's
# patches applied in the spec's order and without fuzz. The DEBs and the source builds of the protocol library
# use this, so every package carries the same code as the RPMs.
#
#   prepare-source.sh <dir> [<patch>...]
#
# Each <patch> after the directory is a carried fix taken out again, for a sabotage run: the src/ part of that
# patch is reversed and the tests it brought stay, so those tests must fail. Needs git.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
spec=$here/mod-host.spec
dir=$(readlink -m "${1:?usage: prepare-source.sh <dir> [<patch to take out>...]}")
shift

commit=$(sed -n 's/^%global commit0 *//p' "$spec")
[[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo "mod-host.spec names no upstream commit" >&2; exit 1; }

mkdir -p "$dir"
git -C "$dir" init -q
for attempt in 1 2 3 4 5; do
    git -C "$dir" fetch -q --depth 1 https://github.com/mod-audio/mod-host "$commit" && break
    [ "$attempt" = 5 ] && { echo "could not fetch mod-host $commit" >&2; exit 1; }
    sleep $((attempt * 3))
done
git -C "$dir" checkout -q FETCH_HEAD
[ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ] || { echo "mod-host is not at $commit" >&2; exit 1; }

for patch in $(sed -n 's/^Patch[0-9]*: *//p' "$spec"); do
    git -C "$dir" apply --whitespace=nowarn "$here/$patch"
done

for patch in "$@"; do
    [ -f "$here/$patch" ] || { echo "no carried patch $patch" >&2; exit 1; }
    git -C "$dir" apply -R --include='src/*' "$here/$patch"
    echo "sabotage: the src/ part of $patch is reversed" >&2
done
