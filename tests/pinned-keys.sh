#!/bin/bash
# The fingerprints the channel's key files are held to (.github/actions/import-gpg-key/pinned-fingerprints.txt).
# The committed list is well formed; every reader of a served key file (channel-keys.sh pinned and check, and
# openmixer-release's build.sh through it) refuses a file holding a key the list does not pin and passes one that
# holds only pinned keys; and a list stripped of the key, empty or missing refuses the same file. Throwaway keys.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
keys=$here/../.github/actions/import-gpg-key/channel-keys.sh
committed=$here/../.github/actions/import-gpg-key/pinned-fingerprints.txt
work=$(mktemp -d)
GNUPGHOME=$work/gnupg
export GNUPGHOME
mkdir -m 700 "$GNUPGHOME"
fail() { echo "FAIL: $*" >&2; exit 1; }

# the committed list: 40 hex digits, a known role, no key twice, at least one packages key and the site key
awk '$1 !~ /^#/ && NF' "$committed" > "$work/lines"
[ -s "$work/lines" ] || fail "the committed list holds no key"
while read -r fpr role _; do
    [[ $fpr =~ ^[0-9A-F]{40}$ ]] || fail "not an upper-case 40 hex fingerprint: $fpr"
    case $role in packages | site) ;; *) fail "unknown role $role for $fpr" ;; esac
done < "$work/lines"
[ "$(cut -d' ' -f1 "$work/lines" | sort | uniq -d | wc -l)" = 0 ] || fail "a fingerprint is listed twice"
grep -q ' packages ' "$work/lines" || fail "no packages key is pinned"
grep -q ' site ' "$work/lines" || fail "the site key is not pinned"

mk() { gpg --batch --quiet --passphrase '' --quick-gen-key "$1 <$1@example.org>" ed25519 sign 1y
    gpg --batch --with-colons --fingerprint "$1@example.org" | awk -F: '/^fpr:/ {print $10; exit}'; }
real=$(mk real)
other=$(mk other)
gpg --batch --armor --export real@example.org > "$work/real.asc"
gpg --batch --armor --export other@example.org > "$work/other.asc"
cat "$work/real.asc" "$work/other.asc" > "$work/both.asc"
export PINNED_FINGERPRINTS=$work/list
pin() { : > "$PINNED_FINGERPRINTS"; for f in "$@"; do printf '%s packages test\n' "$f" >> "$PINNED_FINGERPRINTS"; done; }
refuse() { local what=$1; shift; if "$@" >/dev/null 2>&1; then fail "accepted $what"; fi; }

pin "$real"
"$keys" pinned "$work/real.asc" "$real" >/dev/null || fail "refused a key file of the pinned key"
"$keys" check "$work/real.asc" "$real" >/dev/null || fail "check refused a key file of the pinned key"
refuse "a file with a second, unpinned key" "$keys" pinned "$work/both.asc"
refuse "a file of an unpinned key" "$keys" pinned "$work/other.asc"
refuse "an unpinned signing key" "$keys" pinned "$work/real.asc" "$other"
refuse "check on a file with an unpinned key" "$keys" check "$work/both.asc" "$real"
refuse "serve of an unpinned signing key" "$keys" serve "$work/real.asc" "$other"
pin "$real" "$other"
"$keys" pinned "$work/both.asc" "$real" "$other" >/dev/null || fail "refused a file whose keys are all pinned"

# sabotage the list: the file that passed is refused when the list lacks the key, is empty or is not there
pin "$other"
refuse "a list without the key" "$keys" pinned "$work/real.asc"
pin
refuse "an empty list" "$keys" pinned "$work/real.asc"
rm -f "$PINNED_FINGERPRINTS"
refuse "a missing list" "$keys" pinned "$work/real.asc"

# the committed list stands against a key it does not carry
refuse "a throwaway key against the committed list" env -u PINNED_FINGERPRINTS "$keys" pinned "$work/real.asc"

# openmixer-release ships the served file: build.sh stops at an unpinned key, before it builds anything
pin "$real"
refuse "build.sh on an unpinned key" "$here/../packaging/openmixer-release/build.sh" rpm "$work/both.asc" "$work/out"
out=$("$here/../packaging/openmixer-release/build.sh" rpm "$work/real.asc" "$work/out" 2>&1 || true)
grep -q 'ships' <<< "$out" || fail "build.sh did not get past the pin with a pinned key: $out"
echo "pinned-keys: the list is well formed; unpinned keys and a sabotaged list refused; pinned keys pass"
