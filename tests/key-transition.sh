#!/bin/bash
# A change of release key through the publish scripts, as a channel lives it: a tree signed by OLD_ID, the
# new key served next to it, then a publish signed by NEW_ID. Proves the served key file is a union, that the
# honesty check refuses a key the channel does not serve, and that a client holding only the old key keeps
# installing. Both keys are in the job's keyring (import-gpg-key ran for each).
#
#   key-transition.sh rpm|deb        OLD_ID and NEW_ID in the environment
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
actions=$here/../.github/actions
keys=$actions/import-gpg-key/channel-keys.sh
: "${OLD_ID:?}" "${NEW_ID:?}"
work=$(mktemp -d)
chmod 755 "$work" # apt reads the repository and the signed-by file as _apt
fail() { echo "FAIL: $*" >&2; exit 1; }
served() { gpg --batch --with-colons --import-options show-only --import < "$1" 2>/dev/null |
    awk -F: '/^pub:/ {p = 1; next} /^fpr:/ && p {print $10; p = 0}' | sort | tr '\n' ' '; }
pubring() { gpg --batch --armor --export "$1" > "$work/$2.asc"; gpg --batch --yes --dearmor -o "$work/$2.gpg" "$work/$2.asc"; }
pubring "$OLD_ID" old
pubring "$NEW_ID" new

case "${1:?usage: key-transition.sh rpm|deb}" in
rpm)
    mkpkg() {
        mkdir -p "$work/src-$1"
        printf '%s\n' "Name: $1" 'Version: 1' 'Release: 1.fc44' 'Summary: t' 'License: MIT' 'BuildArch: noarch' \
            '%description' 't' '%files' > "$work/$1.spec"
        rpmbuild -bb --quiet --define "_topdir $work/rb-$1" "$work/$1.spec" >/dev/null 2>&1
        find "$work/rb-$1" -name '*.rpm' -exec cp {} "$work/src-$1/" \;
    }
    tree=$work/rpm
    file=$tree/RPM-GPG-KEY-freemixer
    mkpkg pkg-old
    "$actions/publish-rpms/publish-tree.sh" "$tree" "$work/src-pkg-old" "$OLD_ID"
    [ "$(served "$file")" = "$OLD_ID " ] || fail "the first publish serves $(served "$file"), not $OLD_ID"
    if "$keys" check "$file" "$NEW_ID"; then fail "check accepted $NEW_ID, which the channel does not serve"; fi
    "$keys" serve "$file" "$NEW_ID"
    "$keys" check "$file" "$NEW_ID" "$OLD_ID"
    mkpkg pkg-new
    "$actions/publish-rpms/publish-tree.sh" "$tree" "$work/src-pkg-new" "$NEW_ID"
    want=$(printf '%s\n' "$OLD_ID" "$NEW_ID" | sort | tr '\n' ' ')
    [ "$(served "$file")" = "$want" ] || fail "after the switch the file serves $(served "$file"), want $want"
    for md in "$tree"/fedora/*/*/repodata/repomd.xml; do
        gpgv --keyring "$work/new.gpg" "$md.asc" "$md" 2>/dev/null || fail "$md is not signed by the new key"
    done
    # a client: gpgcheck and repo_gpgcheck on, the served file as gpgkey; the old package keeps its old
    # signature and installs, the new one installs by the new key
    printf '%s\n' '[t]' 'name=t' "baseurl=file://$tree/fedora/44/noarch/" 'gpgcheck=1' 'repo_gpgcheck=1' \
        "gpgkey=file://$file" > /etc/yum.repos.d/t.repo
    dnf -y --disablerepo='*' --enablerepo=t install pkg-old pkg-new
    rpm -q pkg-old pkg-new
    rm -f /etc/yum.repos.d/t.repo
    ;;
deb)
    mkpkg() {
        mkdir -p "$work/$1/DEBIAN" "$work/src-$1/trixie"
        printf '%s\n' "Package: $1" 'Version: 1' 'Architecture: all' 'Maintainer: t <t@example.org>' 'Description: t' \
            > "$work/$1/DEBIAN/control"
        dpkg-deb -b "$work/$1" "$work/src-$1/trixie/${1}_1_all.deb" >/dev/null
    }
    tree=$work/deb
    file=$tree/freemixer.asc
    mkpkg pkg-old
    "$actions/publish-debs/publish-tree.sh" "$tree" "$work/src-pkg-old" "$OLD_ID"
    [ "$(served "$file")" = "$OLD_ID " ] || fail "the first publish serves $(served "$file"), not $OLD_ID"
    if "$keys" check "$file" "$NEW_ID"; then fail "check accepted $NEW_ID, which the channel does not serve"; fi
    "$keys" serve "$file" "$NEW_ID"
    mkpkg pkg-new
    COSIGN=$OLD_ID "$actions/publish-debs/publish-tree.sh" "$tree" "$work/src-pkg-new" "$NEW_ID"
    want=$(printf '%s\n' "$OLD_ID" "$NEW_ID" | sort | tr '\n' ' ')
    [ "$(served "$file")" = "$want" ] || fail "after the switch the file serves $(served "$file"), want $want"
    # gpgv exits non-zero when any signature's key is missing, so read its status lines: each key alone
    # gives one good signature and no bad one (apt, below, is the client's own verdict)
    goodsig() { { gpgv --status-fd 1 --keyring "$@" 2>/dev/null || true; } | awk '/BADSIG/ {b = 1} /VALIDSIG/ {g++} END {exit !(g == 1 && !b)}'; }
    for ring in old new; do
        goodsig "$work/$ring.gpg" "$tree/debian/trixie/InRelease" || fail "InRelease has no good signature by the $ring key"
        goodsig "$work/$ring.gpg" "$tree/debian/trixie/Release.gpg" "$tree/debian/trixie/Release" ||
            fail "Release.gpg has no good signature by the $ring key"
    done
    # a client installed before the switch: its signed-by file holds only the old key
    for ring in old new; do
        echo "deb [signed-by=$work/$ring.asc] file:$tree/debian/trixie ./" > /etc/apt/sources.list.d/t.list
        apt-get update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/t.list -o Dir::Etc::sourceparts=- 2>&1 | tee "$work/apt.log"
        ! grep -qE '^(W|E):' "$work/apt.log" || fail "apt update with the $ring key alone warned or failed"
        apt-get install -y pkg-old pkg-new >/dev/null
        dpkg -s pkg-old pkg-new >/dev/null
        apt-get remove -y pkg-old pkg-new >/dev/null
    done
    rm -f /etc/apt/sources.list.d/t.list
    ;;
*) fail "unknown kind $1" ;;
esac
echo "key transition ($1): PASS"
