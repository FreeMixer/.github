#!/bin/bash
# Add RPMs to a dnf tree laid out as <tree>/fedora/<releasever>/<arch>/ (sources in SRPMS), sign what is
# unsigned, regenerate the metadata of every directory that holds packages (with an updateinfo.xml of one
# advisory per release, made from the packages' %changelog) and sign it.
#
#   publish-tree.sh <tree> <rpm dir> [<gpg key id>]     no key id: an unsigned tree, for inspection only
#
# A package the tree already holds under the same file name is kept whatever the new build's bytes: a
# published NEVRA is immutable and a rebuild that wants in bumps its Release. The tree is shared with
# other projects, so nothing already in it is ever removed.
set -euo pipefail

tree=$(readlink -m "${1:?usage: publish-tree.sh <tree> <rpm dir> [<gpg key id>]}")
src=${2:?usage: publish-tree.sh <tree> <rpm dir> [<gpg key id>]}
key=${3:-}

signed() {
    local sigs
    sigs=$(rpm -qp --qf '%{SIGPGP:pgpsig}|%{SIGGPG:pgpsig}|%{RSAHEADER:pgpsig}|%{DSAHEADER:pgpsig}' "$1" 2>/dev/null) || return 1
    sigs=$(printf '%s' "$sigs" | sed -e 's/(none)//g' -e 's/|//g' -e 's/[[:space:]]//g')
    [ -n "$sigs" ]
}

mapfile -t found < <(find "$src" -name '*.rpm' | sort)
[ "${#found[@]}" -gt 0 ] || { echo "no rpm under $src" >&2; exit 1; }

declare -A dirs=()
for f in "${found[@]}"; do
    IFS='|' read -r is_src arch rel < <(rpm -qp --qf '%{SOURCEPACKAGE}|%{ARCH}|%{RELEASE}\n' "$f")
    [ "$is_src" = 1 ] && archdir=SRPMS || archdir=$arch
    releasever=$(printf '%s\n' "$rel" | sed -n 's/.*\.fc\([0-9][0-9]*\).*/\1/p')
    [ -n "$releasever" ] || { echo "$f has no .fcNN dist tag" >&2; exit 1; }
    dest=$tree/fedora/$releasever/$archdir
    mkdir -p "$dest"
    dirs[$dest]=1
    if [ -f "$dest/$(basename "$f")" ]; then
        echo "kept   $(basename "$f") (already published; a changed build needs a new Release)"
    else
        install -m 0644 "$f" "$dest/"
        echo "placed $(basename "$f") in fedora/$releasever/$archdir"
    fi
done

if [ -n "$key" ]; then
    for dest in "${!dirs[@]}"; do
        for f in "$dest"/*.rpm; do
            signed "$f" || rpmsign --define "_gpg_name $key" --addsign "$f" >/dev/null
            signed "$f" || { echo "unsigned after rpmsign: $f" >&2; exit 1; }
        done
    done
fi

# every directory that holds packages, not only the ones this run placed into: the metadata of the
# pulled tree was discarded, and a directory another project filled would be left bare
while IFS= read -r d; do dirs[$d]=1; done < <(find "$tree" -name '*.rpm' -printf '%h\n' | sort -u)
for dest in "${!dirs[@]}"; do
    if [ -d "$dest/repodata" ]; then createrepo_c --update --quiet "$dest"; else createrepo_c --quiet "$dest"; fi
    # the advisories of the releases this directory holds, from the packages' own changelogs, so that
    # `dnf updateinfo` and `dnf check-update --changelogs` tell a user what an update brings
    if find "$dest" -maxdepth 1 -name '*.rpm' ! -name '*.src.rpm' -print -quit | grep -q .; then
        # createrepo_c --update keeps the record of the last publish: drop it, the new one replaces it
        if grep -q 'type="updateinfo"' "$dest/repodata/repomd.xml"; then
            modifyrepo_c --remove updateinfo "$dest/repodata" >/dev/null
        fi
        updateinfo=$(mktemp -d)
        "$(dirname "$(readlink -f "$0")")/updateinfo.py" "$dest" "$updateinfo/updateinfo.xml"
        modifyrepo_c --mdtype=updateinfo "$updateinfo/updateinfo.xml" "$dest/repodata" >/dev/null
        rm -rf "$updateinfo"
    fi
    rm -f "$dest/repodata/repomd.xml.asc"
    if [ -n "$key" ]; then
        gpg --batch --yes --armor --detach-sign --local-user "$key" \
            --output "$dest/repodata/repomd.xml.asc" "$dest/repodata/repomd.xml"
    fi
    echo "repodata ${dest#"$tree"/}"
done

# the key file is what the channel served plus the signing key, never the signing key alone (channel-keys.sh)
if [ -n "$key" ]; then
    "$(dirname "$(readlink -f "$0")")/../import-gpg-key/channel-keys.sh" serve "$tree/RPM-GPG-KEY-freemixer" "$key"
fi
