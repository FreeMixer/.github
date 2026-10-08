#!/bin/bash
# One human changelog per repository, CHANGELOG.md, from which everything a user sees is generated.
#
#   changelog.sh notes  [-C <tree>] <version>   the release notes of one version, for the GitHub release
#   changelog.sh rpm    [-C <tree>]             the body of the spec's %changelog
#   changelog.sh deb    [-C <tree>] <source>    the whole debian/changelog
#   changelog.sh sync   [-C <tree>] [-s <spec>]  rewrite the spec's %changelog and debian/changelog from CHANGELOG.md
#   changelog.sh check  [-C <tree>] [-t <tag>] [-s <spec>]  refuse a tree whose generated files disagree with CHANGELOG.md,
#                                               and a tag whose version has no entry
#
# CHANGELOG.md holds one section per version, newest first:
#
#   ## 0.1.5 - 2026-10-07
#
#   - What changed for a person who installs the package, in plain words. A bullet may
#     continue on lines indented by two spaces.
#
# A version is <upstream> or <upstream>-<release>; without a release the RPM release is 1. A tag is
# v<version>, the release left out. Headings that are not versions (older notes kept below) are ignored.
# The spec is packaging/*.spec unless -s names it (relative to the tree).
# The author of the generated entries is $CHANGELOG_AUTHOR, Pau Aliagas by default.
set -euo pipefail

author=${CHANGELOG_AUTHOR:-Pau Aliagas <linuxnow@gmail.com>}
tree=.
tag=
spec_arg=

die() { echo "changelog: $*" >&2; exit 1; }

cmd=${1:-}
[ -n "$cmd" ] || die "usage: changelog.sh notes|rpm|deb|sync|check [-C <tree>] ..."
shift
while getopts C:t:s: opt; do
    case $opt in
        C) tree=$OPTARG ;;
        t) tag=$OPTARG ;;
        s) spec_arg=$OPTARG ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
tree=$(readlink -f "$tree")
file=$tree/CHANGELOG.md

# CHANGELOG.md as records: "E<TAB>version<TAB>date" opens an entry, "B<TAB>text" is one bullet with its
# continuation lines joined. A malformed version section is an error, not a silent skip.
parse() {
    [ -f "$file" ] || die "$tree has no CHANGELOG.md"
    awk '
        function flush() { if (text != "") print "B\t" text; text = "" }
        /^## / {
            flush()
            ver = $2
            if ($0 ~ /^## [0-9][0-9A-Za-z.~+]*(-[0-9]+)? - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
                print "E\t" $2 "\t" $4; inentry = 1
            } else if ($0 ~ /^## [0-9]+\.[0-9]/) {
                print "changelog: malformed heading (want \"## <version> - YYYY-MM-DD\"): " $0 > "/dev/stderr"; bad = 1; inentry = 0
            } else inentry = 0
            next
        }
        !inentry { next }
        /^- / { flush(); text = substr($0, 3); next }
        /^  [^ ]/ { if (text == "") { print "changelog: continuation outside a bullet: " $0 > "/dev/stderr"; bad = 1 } else { sub(/^  /, ""); text = text " " $0 }; next }
        /^[ \t]*$/ { flush(); next }
        { print "changelog: not a bullet or its continuation: " $0 > "/dev/stderr"; bad = 1 }
        END { flush(); exit bad }
    ' "$file"
}

# wrap <first prefix> <continuation prefix> <width>: one bullet per input line
wrap() {
    awk -v first="$1" -v rest="$2" -v width="$3" '
        {
            line = first; n = split($0, w, " "); col = length(first); startofline = 1
            for (i = 1; i <= n; i++) {
                if (!startofline && col + 1 + length(w[i]) > width) { print line; line = rest; col = length(rest); startofline = 1 }
                if (startofline) { line = line w[i]; col += length(w[i]); startofline = 0 }
                else { line = line " " w[i]; col += 1 + length(w[i]) }
            }
            print line
        }'
}

rpm_version() { case $1 in *-[0-9]*) printf '%s' "$1" ;; *) printf '%s-1' "$1" ;; esac; }

# render <format>: every entry, newest first. Entries that share a date get a minute each, so the Debian
# timestamps strictly increase with the version: the oldest of a date at 12:00, each newer one a minute later.
render() {
    local fmt=$1 src=${2:-} kind a b i j n first=1
    local ver= date= bullets=
    local -a vers=() dates=() bodies=()
    while IFS=$'\t' read -r kind a b; do
        if [ "$kind" = E ] || [ "$kind" = END ]; then
            if [ -n "$ver" ]; then vers+=("$ver"); dates+=("$date"); bodies+=("$bullets"); fi
            ver=$a date=$b bullets=
        else
            bullets+=$a$'\n'
        fi
    done < <(parse; echo END)
    for ((i = 0; i < ${#vers[@]}; i++)); do
        n=0
        for ((j = i + 1; j < ${#vers[@]}; j++)); do
            if [ "${dates[j]}" = "${dates[i]}" ]; then n=$((n + 1)); fi
        done
        emit_entry "$fmt" "$src" "${vers[i]}" "${dates[i]}" "${bodies[i]}" "$n"
    done
}

# emit_entry <format> <source> <version> <date> <bullets> <minutes after 12:00 UTC>
emit_entry() {
    local fmt=$1 src=$2 ver=$3 date=$4 bullets=$5 mins=$6 stamp
    [ -n "$bullets" ] || die "version $ver has no bullet"
    if [ "$fmt" = rpm ]; then
        stamp=$(LC_ALL=C date -u -d "$date 12:00:00" +'%a %b %d %Y')
        [ "$first" = 1 ] || echo
        printf '* %s %s - %s\n' "$stamp" "$author" "$(rpm_version "$ver")"
        printf '%s' "$bullets" | sed 's/%/%%/g' | wrap '- ' '  ' 78
    else
        stamp=$(LC_ALL=C date -u -d "$date 12:00:00 UTC +$mins minutes" -R)
        [ "$first" = 1 ] || echo
        printf '%s (%s) unstable; urgency=medium\n\n' "$src" "$ver"
        printf '%s' "$bullets" | wrap '  * ' '    ' 78
        printf '\n -- %s  %s\n' "$author" "$stamp"
    fi
    first=0
}

top_version() { parse | awk -F'\t' '$1 == "E" { print $2; exit }'; }

spec_of() {
    local found
    if [ -n "$spec_arg" ]; then
        [ -f "$tree/$spec_arg" ] || die "$tree/$spec_arg does not exist"
        printf '%s' "$tree/$spec_arg"
        return
    fi
    found=$(ls "$tree"/packaging/*.spec 2>/dev/null || true)
    [ "$(printf '%s' "$found" | grep -c .)" -le 1 ] || die "$tree/packaging holds more than one spec: name it with -s"
    printf '%s' "$found"
}
spec_changelog() { awk '/^%changelog[ \t]*$/ { p = 1; next } p' "$1" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

sync_spec() {
    local spec=$1 new
    grep -q '^%changelog[ \t]*$' "$spec" || die "$spec has no %changelog"
    spec_changelog "$spec" | grep -q '^%[a-z]' && die "$spec has a section after %changelog"
    new=$(mktemp)
    { awk '{ print } /^%changelog[ \t]*$/ { exit }' "$spec"; render rpm; } > "$new"
    cat "$new" > "$spec"
    rm -f "$new"
}

source_name() { sed -n 's/^Source: *//p' "$tree/debian/control" | head -1; }

case $cmd in
    notes)
        v=${1:?usage: changelog.sh notes [-C <tree>] <version>}
        out=$(parse | awk -F'\t' -v v="$v" '
            $1 == "E" { on = ($2 == v) || (index($2, v "-") == 1); found = found || on; next }
            on && $1 == "B" { print $2 }')
        [ -n "$out" ] || die "CHANGELOG.md has no entry for $v"
        printf '%s\n' "$out" | wrap '- ' '  ' 100
        ;;
    rpm) render rpm ;;
    deb) render deb "${1:?usage: changelog.sh deb [-C <tree>] <source>}" ;;
    sync)
        parse >/dev/null
        spec=$(spec_of)
        [ -z "$spec" ] || sync_spec "$spec"
        if [ -f "$tree/debian/control" ]; then render deb "$(source_name)" > "$tree/debian/changelog"; fi
        ;;
    check)
        fail=0
        bad() { echo "changelog: $*" >&2; fail=1; }
        parse >/dev/null || exit 1
        top=$(top_version)
        [ -n "$top" ] || die "CHANGELOG.md has no version section"
        dups=$(parse | awk -F'\t' '$1 == "E" { print $2 }' | sort | uniq -d)
        [ -z "$dups" ] || bad "versions listed twice: $dups"
        order=$(parse | awk -F'\t' '$1 == "E" { if (prev != "" && $3 > prev) print $2 " is dated after the entry below it"; prev = $3 }')
        [ -z "$order" ] || bad "$order"
        if [ -n "$tag" ]; then
            want=${top%%-*}
            [ "$tag" = "v$want" ] || bad "tag $tag, but the newest CHANGELOG.md entry is $top: a release is the newest entry, so add the entry for ${tag#v} first"
            parse | awk -F'\t' -v t="${tag#v}" '$1 == "E" && (($2 == t) || (index($2, t "-") == 1)) { f = 1 } END { exit !f }' ||
                bad "CHANGELOG.md has no entry for ${tag#v}"
        fi
        spec=$(spec_of)
        if [ -n "$spec" ]; then
            ver=$(sed -n 's/^Version: *//p' "$spec" | head -1)
            rel=$(sed -n 's/^Release: *\([0-9][0-9]*\).*/\1/p' "$spec" | head -1)
            case $ver in
                *%*) ;;
                *) [ "$ver" = "${top%%-*}" ] || bad "$spec says Version $ver, CHANGELOG.md says $top" ;;
            esac
            [ "$(rpm_version "$top")" = "${top%%-*}-${rel:-1}" ] || bad "$spec says Release ${rel:-1}, CHANGELOG.md says $top"
            if ! diff <(spec_changelog "$spec") <(render rpm) >/dev/null; then
                bad "the %changelog of $spec is not what CHANGELOG.md generates; run: changelog.sh sync"
                diff <(spec_changelog "$spec") <(render rpm) | head -20 >&2 || true
            fi
        fi
        if [ -f "$tree/debian/control" ]; then
            [ -f "$tree/debian/changelog" ] || bad "debian/changelog is missing"
            if ! diff "$tree/debian/changelog" <(render deb "$(source_name)") >/dev/null; then
                bad "debian/changelog is not what CHANGELOG.md generates; run: changelog.sh sync"
                diff "$tree/debian/changelog" <(render deb "$(source_name)") | head -20 >&2 || true
            fi
        fi
        [ "$fail" = 0 ] || exit 1
        echo "changelog: $top: CHANGELOG.md and what it generates agree"
        ;;
    *) die "unknown command $cmd" ;;
esac
