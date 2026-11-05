#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# The release record of the source packages a publish served: for each <name>-*.src.rpm in <dir>, one built per
# Fedora release of the matrix, where the channel serves it and its sha256, so a consumer can pin it. Exits 1 when
# <dir> holds none, or one whose Release names no Fedora release.
#
#   record-srpm.sh <dir> <name> [<base url>]
set -euo pipefail

dir=${1:?usage: record-srpm.sh <dir> <name> [<base url>]}
name=${2:?usage: record-srpm.sh <dir> <name> [<base url>]}
base=${3:-https://www.openmixer.org/rpm}

found=0
echo "### Source packages"
echo
while IFS= read -r srpm; do
    found=$((found + 1))
    file=$(basename "$srpm")
    rel=$(rpm -qp --qf '%{RELEASE}' "$srpm" | sed -n 's/.*\.fc\([0-9][0-9]*\).*/\1/p')
    [ -n "$rel" ] || { echo "::error::$file names no Fedora release in its Release" >&2; exit 1; }
    echo "- fedora $rel: $base/fedora/$rel/SRPMS/$file"
    echo "  sha256: $(sha256sum "$srpm" | cut -d' ' -f1)"
done < <(find "$dir" -maxdepth 1 -name "$name-[0-9]*.src.rpm" | sort)
[ "$found" -gt 0 ] || { echo "::error::no $name source package under $dir" >&2; exit 1; }
