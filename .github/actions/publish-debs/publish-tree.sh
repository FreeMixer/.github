#!/bin/bash
# Add DEBs to an apt tree of flat repositories laid out as <tree>/debian/<suite>/<arch>/, regenerate the
# index of every suite and sign it.
#
#   publish-tree.sh <tree> <deb dir> [<gpg key id>]     no key id: an unsigned tree, for inspection only
#
# <deb dir> holds <suite>/<package>.deb, the suite being the Debian release the package was built on. A
# package the tree already holds under the same file name is kept whatever the new build's bytes: a
# published version is immutable and a rebuild that wants in bumps its version. The tree is shared with
# other projects, so nothing already in it is ever removed. REQUIRES names packages that must be in the tree
# for every suite and architecture this run places a package into, so a package is never published without
# a dependency of it that no repository serves.
set -euo pipefail

tree=$(readlink -m "${1:?usage: publish-tree.sh <tree> <deb dir> [<gpg key id>]}")
src=${2:?usage: publish-tree.sh <tree> <deb dir> [<gpg key id>]}
key=${3:-}
requires=${REQUIRES:-}

mapfile -t found < <(find "$src" -name '*.deb' | sort)
[ "${#found[@]}" -gt 0 ] || { echo "no deb under $src" >&2; exit 1; }

declare -A cells=()
for f in "${found[@]}"; do
    suite=$(basename "$(dirname "$f")")
    arch=$(dpkg-deb -f "$f" Architecture)
    dest=$tree/debian/$suite/$arch
    mkdir -p "$dest"
    cells[$suite/$arch]=1
    if [ -f "$dest/$(basename "$f")" ]; then
        echo "kept   $(basename "$f") (already published; a changed build needs a new version)"
    else
        install -m 0644 "$f" "$dest/"
        echo "placed $(basename "$f") in debian/$suite/$arch"
    fi
done

for cell in "${!cells[@]}"; do
    for pkg in $requires; do
        compgen -G "$tree/debian/$cell/${pkg}_*.deb" >/dev/null ||
            { echo "debian/$cell holds no $pkg: publish it first (workflow mod-host-protocol-deb of FreeMixer/.github)" >&2; exit 1; }
    done
done

for suitedir in "$tree"/debian/*/; do
    suite=$(basename "$suitedir")
    (
        cd "$suitedir"
        rm -f Packages Packages.gz Release InRelease Release.gpg
        archs=$(find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | tr '\n' ' ')
        apt-ftparchive packages . > Packages
        gzip -9nk Packages
        release=$(mktemp)
        apt-ftparchive \
            -o APT::FTPArchive::Release::Origin=FreeMixer -o APT::FTPArchive::Release::Label=FreeMixer \
            -o APT::FTPArchive::Release::Suite="$suite" -o APT::FTPArchive::Release::Codename="$suite" \
            -o APT::FTPArchive::Release::Architectures="${archs% }" \
            release . > "$release"
        cat "$release" > Release
        rm -f "$release"
        if [ -n "$key" ]; then
            gpg --batch --yes --armor --detach-sign --local-user "$key" --output Release.gpg Release
            gpg --batch --yes --clearsign --local-user "$key" --output InRelease Release
        fi
    )
    echo "index debian/$suite"
done

if [ -n "$key" ]; then
    gpg --armor --export "$key" > "$tree/freemixer.asc"
    [ -s "$tree/freemixer.asc" ] || { echo "exporting $key gave an empty key file" >&2; exit 1; }
fi
