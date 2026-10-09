#!/bin/bash
# Git history is the changelog: no file is kept by hand. Everything a user sees is made from the commit
# subjects between the previous tag and the release.
#
#   changelog.sh notes [-C <tree>] [<ref>]                   the release notes: "- <subject>" per commit
#   changelog.sh rpm   [-C <tree>] [<ref>] <version-release>  the body of the spec's %changelog (one entry)
#   changelog.sh deb   [-C <tree>] [<ref>]                   rewrite debian/changelog's top entry from git
#
# <ref> is a tag or HEAD (default HEAD). The range is <previous tag>..<ref>, merge commits left out; with no
# previous tag it is all of <ref>'s history. The tree needs its tags and history (fetch-depth: 0).
# The author of generated entries is $CHANGELOG_AUTHOR, Pau Aliagas by default.
set -euo pipefail

author=${CHANGELOG_AUTHOR:-Pau Aliagas <linuxnow@gmail.com>}
die() { echo "changelog: $*" >&2; exit 1; }

cmd=${1:-}
[ -n "$cmd" ] || die "usage: changelog.sh notes|rpm|deb [-C <tree>] [<ref>] ..."
shift
tree=.
while getopts C: opt; do
    case $opt in
        C) tree=$OPTARG ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
git() { command git -c safe.directory="$(readlink -f "$tree")" -C "$tree" "$@"; }

ref=${1:-HEAD}
git rev-parse --verify -q "$ref^{commit}" >/dev/null || die "$ref is not a commit of $tree"

subjects() {
    local prev
    prev=$(git describe --tags --abbrev=0 "$ref^" 2>/dev/null || true)
    git log --no-merges --format='%s' "${prev:+$prev..}$ref"
}

case $cmd in
    notes)
        out=$(subjects | sed 's/^/- /')
        [ -n "$out" ] || out="- $(git log -1 --format=%s "$ref")"
        printf '%s\n' "$out"
        ;;
    rpm)
        vr=${2:?usage: changelog.sh rpm [-C <tree>] <ref> <version-release>}
        date=$(LC_ALL=C TZ=UTC git log -1 --format=%cd --date=format-local:'%a %b %d %Y' "$ref")
        printf '* %s %s - %s\n' "$date" "$author" "$vr"
        # a macro in a subject would be expanded by rpm
        subjects | sed -e 's/%/%%/g' -e 's/^/- /'
        printf '\n'
        ;;
    deb)
        file=$tree/debian/changelog
        [ -f "$file" ] || die "$tree has no debian/changelog"
        head=$(head -n 1 "$file")
        case $head in *' ('*') '*';'*) ;; *) die "debian/changelog does not open with an entry" ;; esac
        date=$(LC_ALL=C TZ=UTC git log -1 --format=%cd --date=format-local:'%a, %d %b %Y %H:%M:%S +0000' "$ref")
        # one bullet per subject; a folded subject continues under it
        body=$(subjects | while IFS= read -r s; do
            printf '%s\n' "$s" | fold -s -w 74 | sed -e 's/[[:space:]]*$//' -e '1s/^/  * /' -e '2,$s/^/    /'
        done)
        [ -n "$body" ] || body="  * $(git log -1 --format=%s "$ref")"
        { printf '%s\n\n%s\n\n -- %s  %s\n' "$head" "$body" "$author" "$date"; } > "$file"
        ;;
    *) die "unknown command $cmd" ;;
esac
