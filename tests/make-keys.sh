#!/bin/bash
# Two throwaway release keys in a scratch keyring, written armored to <dir>/old.sec and <dir>/new.sec:
#   old  a full secret key behind a passphrase (the shape of the key the channel started with)
#   new  a certify-only primary whose signing subkey is exported alone, without a passphrase (the shape
#        of the openmixer packages key: the primary travels as a stub)
set -euo pipefail
dir=${1:?usage: make-keys.sh <dir>}
mkdir -p "$dir"
GNUPGHOME=$(mktemp -d)
export GNUPGHOME
gpg --batch --quiet --pinentry-mode loopback --passphrase old-pass --quick-gen-key 'Old Key <old@example.org>' ed25519 sign 1y
gpg --batch --quiet --pinentry-mode loopback --passphrase old-pass --armor --export-secret-keys old@example.org > "$dir/old.sec"
gpg --batch --quiet --passphrase '' --quick-gen-key 'New Key <new@example.org>' ed25519 cert 2y
fpr=$(gpg --with-colons --fingerprint new@example.org | awk -F: '/^fpr:/ {print $10; exit}')
gpg --batch --quiet --passphrase '' --quick-add-key "$fpr" ed25519 sign 1y
sub=$(gpg --with-colons --fingerprint --fingerprint new@example.org | awk -F: '/^sub:/ {s = 1; next} /^fpr:/ && s {print $10; exit}')
gpg --batch --quiet --pinentry-mode loopback --passphrase '' --armor --export-secret-subkeys "$sub!" > "$dir/new.sec"
rm -rf "$GNUPGHOME"
