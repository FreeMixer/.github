#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# already-served.sh <tag> <package>...   (paths of the channel tree on stdin)
#
# Exits 1, naming the file, when the tree holds a package of the given names at the version the tag names:
#   rpm/**/<name>-<version>-<release>.<arch>.rpm      deb/**/<name>_<version>[-<revision>]_<arch>.deb
# Names may be globs. A tag that is not v<version> names no version and passes. KIND=rpm or KIND=deb reads only that
# half of the tree (a release's deb job must not be refused by the rpms its own rpm job just published); empty reads both.
set -uo pipefail
tag=$1; shift
ver=${tag#v}
[ "$ver" != "$tag" ] || exit 0
found=
while IFS= read -r path; do
  base=${path##*/}
  case $path in
    rpm/*.rpm) [ "${KIND:-}" != deb ] || continue ;;
    deb/*.deb) [ "${KIND:-}" != rpm ] || continue ;;
    *) continue ;;
  esac
  for name in "$@"; do
    # shellcheck disable=SC2254 # name is a glob on purpose
    case $base in
      ${name}-${ver}-*.rpm|${name}_${ver}-*.deb|${name}_${ver}_*.deb) found="$found $path"; break ;;
    esac
  done
done
if [ -n "$found" ]; then
  for f in $found; do echo "::error::$tag is already served: $f (the channel holds this version; bump the version, or set republish for a rerun that must finish a partial publish)"; done
  exit 1
fi
echo "$tag is not served yet"
