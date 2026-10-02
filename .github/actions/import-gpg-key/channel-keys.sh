#!/bin/bash
# The public key files a channel serves (rpm/RPM-GPG-KEY-freemixer, deb/freemixer.asc).
#
#   channel-keys.sh check <key file> <fingerprint>...   every fingerprint is a primary the file serves
#   channel-keys.sh serve <key file> <key id>...        the file becomes what it served plus these keys
#
# A served key file is a UNION and only grows: a client that imported an earlier key keeps verifying what
# that key signed, and a new signing key is served next to the old one, never in its place. dnf imports
# from the gpgkey URL the key a package or repomd.xml names; apt reads the signed-by copy the user saved,
# so for apt the index is co-signed while the old key is still in users' keyrings (publish-debs). A key
# leaves the file only by a hand commit to the channel, when its retirement is decided.
#
# check with no file (the first publish into an empty channel) warns and passes: there is nothing yet a
# client could have imported.
set -euo pipefail

primaries() { gpg --batch --with-colons --import-options show-only --import 2>/dev/null |
    awk -F: '/^pub:/ {p = 1; next} /^fpr:/ && p {print $10; p = 0}'; }

cmd=${1:?usage: channel-keys.sh check|serve <key file> <key>...}
file=${2:?usage: channel-keys.sh check|serve <key file> <key>...}
shift 2
[ "$#" -gt 0 ] || { echo "channel-keys.sh $cmd: no key named" >&2; exit 2; }

case "$cmd" in
check)
    if [ ! -s "$file" ]; then
        echo "::warning::the channel serves no public key at $file yet: this publish sets it to $*"
        exit 0
    fi
    served=$(primaries < "$file")
    [ -n "$served" ] || { echo "::error::no fingerprint readable from $file"; exit 1; }
    for fpr in "$@"; do
        grep -qx "$fpr" <<< "$served" || {
            echo "::error::the signing key $fpr is not one the channel serves at $file ($(tr '\n' ' ' <<< "$served")) -- refusing to sign with a key clients cannot verify"
            exit 1
        }
    done
    echo "$file serves $(tr '\n' ' ' <<< "$served")"
    ;;
serve)
    home=$(mktemp -d)
    trap 'rm -rf "$home"' EXIT
    { if [ -s "$file" ]; then cat "$file"; fi; gpg --armor --export "$@"; } |
        GNUPGHOME=$home gpg --batch --quiet --import 2>/dev/null
    GNUPGHOME=$home gpg --batch --armor --export > "$file.new"
    for k in "$@"; do
        fpr=$(gpg --batch --with-colons --fingerprint "$k" | awk -F: '/^fpr:/ {print $10; exit}')
        grep -qx "$fpr" < <(primaries < "$file.new") || { echo "exporting $k left it out of $file" >&2; rm -f "$file.new"; exit 1; }
    done
    mv "$file.new" "$file"
    ;;
*)
    echo "channel-keys.sh: unknown command $cmd" >&2
    exit 2
    ;;
esac
