#!/bin/bash
# A channel write must not become a signed package. The publish scripts pull the channel's tree, so a
# package someone left in it reaches the run: an unsigned RPM, an RPM signed by a key the channel does not
# serve, a .deb the signed index never listed, or one swapped under a listed name. Each makes the publish
# refuse, names the file, signs nothing and leaves the planted file as it was; once it is gone the same
# publish passes. Throwaway keys in a scratch keyring.
#
#   sign-only-placed.sh rpm|deb
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
actions=$here/../.github/actions
work=$(mktemp -d)
GNUPGHOME=$work/gnupg
export GNUPGHOME
mkdir -m 700 "$GNUPGHOME"
fail() { echo "FAIL: $*" >&2; exit 1; }
gpg --batch --quiet --passphrase '' --quick-gen-key 'Release <release@example.org>' ed25519 sign 1y
gpg --batch --quiet --passphrase '' --quick-gen-key 'Intruder <intruder@example.org>' ed25519 sign 1y
key=$(gpg --batch --with-colons --fingerprint release@example.org | awk -F: '/^fpr:/ {print $10; exit}')

# <publish command...>: must refuse, naming <name>; prints nothing else
refuses() {
    local name=$1 out
    shift
    if out=$("$@" 2>&1); then fail "the publish accepted a tree holding $name: $out"; fi
    grep -q "refused .*$name" <<< "$out" || fail "the refusal does not name $name: $out"
    grep -q 'nothing was signed' <<< "$out" || fail "the refusal does not say nothing was signed: $out"
}

case "${1:?usage: sign-only-placed.sh rpm|deb}" in
rpm)
    mkpkg() {
        mkdir -p "$work/src-$1"
        printf '%s\n' "Name: $1" 'Version: 1' 'Release: 1.fc44' 'Summary: t' 'License: MIT' 'BuildArch: noarch' \
            '%description' 't' '%files' > "$work/$1.spec"
        rpmbuild -bb --quiet --define "_topdir $work/rb-$1" "$work/$1.spec" >/dev/null 2>&1
        find "$work/rb-$1" -name '*.rpm' -exec cp {} "$work/src-$1/" \;
    }
    sigs() { rpm -qp --qf '%{RSAHEADER:pgpsig}%{DSAHEADER:pgpsig}' "$1" 2>/dev/null | sed 's/(none)//g'; }
    tree=$work/rpm
    dir=$tree/fedora/44/noarch
    publish() { "$actions/publish-rpms/publish-tree.sh" "$tree" "$work/src-$1" "$key"; }
    mkpkg pkg-a
    mkpkg pkg-b
    mkpkg evil
    publish pkg-a >/dev/null
    [ -n "$(sigs "$dir/pkg-a-1-1.fc44.noarch.rpm")" ] || fail "the first publish left its own package unsigned"
    repomd=$(sha256sum < "$dir/repodata/repomd.xml")

    # an unsigned package planted in the channel stays unsigned and stops the publish
    cp "$work/src-evil/evil-1-1.fc44.noarch.rpm" "$dir/"
    refuses evil-1-1.fc44.noarch.rpm publish pkg-b
    [ -z "$(sigs "$dir/evil-1-1.fc44.noarch.rpm")" ] || fail "the planted package was signed"
    [ -z "$(sigs "$dir/pkg-b-1-1.fc44.noarch.rpm")" ] || fail "the refused run still signed its own package"
    [ "$(sha256sum < "$dir/repodata/repomd.xml")" = "$repomd" ] || fail "the refused run rewrote the metadata"

    # signed, but by a key the channel does not serve
    rm -f "$dir/evil-1-1.fc44.noarch.rpm" "$dir/pkg-b-1-1.fc44.noarch.rpm"
    cp "$work/src-evil/evil-1-1.fc44.noarch.rpm" "$dir/"
    rpmsign --define '_gpg_name intruder@example.org' --addsign "$dir/evil-1-1.fc44.noarch.rpm" >/dev/null 2>&1
    refuses evil-1-1.fc44.noarch.rpm publish pkg-b

    # gone again: the same publish passes, its package signed and the earlier one untouched
    rm -f "$dir/evil-1-1.fc44.noarch.rpm" "$dir/pkg-b-1-1.fc44.noarch.rpm"
    publish pkg-b >/dev/null
    [ -n "$(sigs "$dir/pkg-b-1-1.fc44.noarch.rpm")" ] || fail "a clean publish left its package unsigned"
    [ -n "$(sigs "$dir/pkg-a-1-1.fc44.noarch.rpm")" ] || fail "a clean publish lost the earlier package's signature"
    ;;
deb)
    mkpkg() {
        mkdir -p "$work/$1-$2/DEBIAN" "$work/src-$1-$2/trixie"
        printf '%s\n' "Package: $1" "Version: 1" 'Architecture: all' 'Maintainer: t <t@example.org>' "Description: $2" \
            > "$work/$1-$2/DEBIAN/control"
        dpkg-deb -b "$work/$1-$2" "$work/src-$1-$2/trixie/${1}_1_all.deb" >/dev/null
    }
    tree=$work/deb
    suite=$tree/debian/trixie
    publish() { "$actions/publish-debs/publish-tree.sh" "$tree" "$work/src-$1" "$key"; }
    mkpkg pkg-a real
    mkpkg pkg-a swapped
    mkpkg pkg-b real
    mkpkg evil real
    publish pkg-a-real >/dev/null
    inrelease=$(sha256sum < "$suite/InRelease")

    # a package the signed index never listed
    cp "$work/src-evil-real/trixie/evil_1_all.deb" "$suite/all/"
    refuses evil_1_all.deb publish pkg-b-real
    [ "$(sha256sum < "$suite/InRelease")" = "$inrelease" ] || fail "the refused run re-signed the index"
    rm -f "$suite/all/evil_1_all.deb" "$suite/all/pkg-b_1_all.deb"

    # a listed name with other bytes
    cp "$suite/all/pkg-a_1_all.deb" "$work/pkg-a.keep"
    cp "$work/src-pkg-a-swapped/trixie/pkg-a_1_all.deb" "$suite/all/"
    refuses pkg-a_1_all.deb publish pkg-b-real
    cp "$work/pkg-a.keep" "$suite/all/pkg-a_1_all.deb"
    rm -f "$suite/all/pkg-b_1_all.deb"

    # a planted package listed in a Packages file the signed InRelease does not name
    cp "$work/src-evil-real/trixie/evil_1_all.deb" "$suite/all/"
    cp "$suite/Packages" "$work/Packages.keep"
    (cd "$suite" && apt-ftparchive packages . > Packages)
    refuses evil_1_all.deb publish pkg-b-real
    cp "$work/Packages.keep" "$suite/Packages"
    rm -f "$suite/all/evil_1_all.deb" "$suite/all/pkg-b_1_all.deb"

    # gone again: the same publish passes and the index lists both
    publish pkg-b-real >/dev/null
    grep -q '^Package: pkg-b$' "$suite/Packages" || fail "a clean publish did not index its package"
    grep -q '^Package: pkg-a$' "$suite/Packages" || fail "a clean publish dropped the earlier package"
    [ "$(sha256sum < "$suite/InRelease")" != "$inrelease" ] || fail "a clean publish did not re-sign the index"
    ;;
*)
    fail "usage: sign-only-placed.sh rpm|deb"
    ;;
esac
echo "sign-only-placed $1: planted packages refused, nothing signed; clean publish passes"
