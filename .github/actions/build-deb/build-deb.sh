#!/bin/bash
# Build the DEBs of a tree from its debian/ directory and lint them.
#
#   build-deb.sh [-C <tree>] [-t <release tag>] <output dir>
#
# The version is the tree's debian/changelog; when the tree also carries a packaging/*.spec its Version
# must be the same, one release cannot be two versions. With -t the tag must be v<version> and the tree
# must be that tag's commit; without it the build is a snapshot: the top changelog entry becomes <version>~git<short sha>,
# which sorts below the release. Lintian warnings fail the build; a tag that is deliberate carries an
# override with its reason in debian/.
set -euo pipefail

tree=.
tag=
while getopts C:t: opt; do
    case $opt in
        C) tree=$OPTARG ;;
        t) tag=$OPTARG ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
mkdir -p "${1:?usage: build-deb.sh [-C <tree>] [-t <release tag>] <output dir>}"
out=$(readlink -f "$1")
tree=$(readlink -f "$tree")
cd "$tree"

[ -f debian/changelog ] || { echo "$tree has no debian/changelog" >&2; exit 1; }
version=$(dpkg-parsechangelog -S Version)
name=$(dpkg-parsechangelog -S Source)
for spec in packaging/*.spec; do
    [ -f "$spec" ] || continue
    specver=$(sed -n 's/^Version: *//p' "$spec")
    [ "$specver" = "$version" ] || { echo "debian/changelog says $version, $spec says $specver" >&2; exit 1; }
done

short=$(git rev-parse --short HEAD)
if [ -n "$tag" ]; then
    [ "$tag" = "v$version" ] || { echo "tag $tag is not v$version, the changelog's version" >&2; exit 1; }
    [ "$(git rev-parse "$tag^{commit}")" = "$(git rev-parse HEAD)" ] || { echo "the tree is not at $tag" >&2; exit 1; }
else
    sed -i "1s/^\\(\\S\\+\\) (\\([^)]*\\))/\\1 ($version~git$short)/" debian/changelog
fi

apt-get build-dep -y --no-install-recommends ./
dpkg-buildpackage -b -uc -us

changes=$(ls ../"${name}"_*.changes)
lintian --fail-on error,warning "$changes"

find .. -maxdepth 1 -name '*.deb' ! -name '*-dbgsym_*' -exec cp {} "$out/" \;
ls "$out"/*.deb
