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
#
# COSIGN names a second key that also signs Release.gpg and InRelease (apt verifies with any key of the
# signed-by file, and one good signature from it is enough). It carries a key change: apt users hold the
# key file they saved at install time, so while it holds only the old key the index keeps a signature by
# that key. Only the apt index is co-signed; packages and the dnf metadata carry the signing key alone.
set -euo pipefail

tree=$(readlink -m "${1:?usage: publish-tree.sh <tree> <deb dir> [<gpg key id>]}")
src=${2:?usage: publish-tree.sh <tree> <deb dir> [<gpg key id>]}
key=${3:-}
requires=${REQUIRES:-}
cosign=${COSIGN:-}
# CHANGELOGS_URL is where the tree's changelogs/ directory is served; empty leaves the Release file without a Changelogs field
changelogs=${CHANGELOGS_URL:+${CHANGELOGS_URL%/}/@CHANGEPATH@_changelog}
[ -z "$cosign" ] || [ -n "$key" ] || { echo "COSIGN needs a signing key" >&2; exit 1; }
signers=()
for k in $key $cosign; do signers+=(--local-user "$k"); done

# apt changelog for a version that is not installed yet asks the Changelogs: URL of the Release file for
# <source>_<version>_changelog under CHANGEPATH (prefix/source (a flat repository has no component)). The text is the package's own
# changelog, the one the .deb carries for apt-listchanges and for the installed version. A file already
# there is kept: a published version's changelog does not change.
place_changelog() {
    local deb=$1 pkg ver srcfield source srcver prefix dir member
    pkg=$(dpkg-deb -f "$deb" Package)
    ver=$(dpkg-deb -f "$deb" Version)
    srcfield=$(dpkg-deb -f "$deb" Source 2>/dev/null || true)
    source=${srcfield%% *}
    source=${source:-$pkg}
    case $srcfield in *"("*")"*) srcver=${srcfield#*(}; srcver=${srcver%)*} ;; *) srcver=$ver ;; esac
    srcver=${srcver#*:}
    case $source in lib*) prefix=${source:0:4} ;; *) prefix=${source:0:1} ;; esac
    dir=$tree/changelogs/$prefix/$source
    [ ! -f "$dir/${source}_${srcver}_changelog" ] || return 0
    member=$(dpkg-deb --fsys-tarfile "$deb" | tar -t | sed 's|^\./||' |
        grep -xE "usr/share/doc/$pkg/changelog(\.Debian)?\.gz" | sort | head -1 || true)
    # a package whose doc directory links to another package's carries no changelog of its own
    [ -n "$member" ] || return 0
    mkdir -p "$dir"
    dpkg-deb --fsys-tarfile "$deb" | tar -xO "./$member" | gzip -dc > "$dir/${source}_${srcver}_changelog"
    echo "changelog $source $srcver"
}

mapfile -t found < <(find "$src" -name '*.deb' | sort)
[ "${#found[@]}" -gt 0 ] || { echo "no deb under $src" >&2; exit 1; }

declare -A cells=()
for f in "${found[@]}"; do
    [ "$(dirname "$(dirname "$f")")" = "${src%/}" ] || { echo "$f is not laid out <suite>/<package>.deb under $src" >&2; exit 1; }
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

# every package of the tree, so a release published before the Changelogs field existed gets its file too
while IFS= read -r f; do place_changelog "$f"; done < <(find "$tree/debian" -name '*.deb' | sort)

for cell in "${!cells[@]}"; do
    # an Architecture: all package installs beside the arch cells, which hold the required libraries
    [ "${cell##*/}" = all ] && continue
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
        # where apt changelog finds the changelog of a version it has not installed (place_changelog)
        if [ -n "$changelogs" ]; then
            sed -i "/^Architectures:/a Changelogs: $changelogs" "$release"
        fi
        cat "$release" > Release
        rm -f "$release"
        if [ -n "$key" ]; then
            gpg --batch --yes --armor --detach-sign "${signers[@]}" --output Release.gpg Release
            gpg --batch --yes --clearsign "${signers[@]}" --output InRelease Release
        fi
    )
    echo "index debian/$suite"
done

# the key file is what the channel served plus every key that signed the index (channel-keys.sh)
if [ -n "$key" ]; then
    # shellcheck disable=SC2086 # cosign is one key id or empty
    "$(dirname "$(readlink -f "$0")")/../import-gpg-key/channel-keys.sh" serve "$tree/freemixer.asc" "$key" $cosign
fi
