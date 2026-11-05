#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# The installed Surge XT loads in the hosts' own scanners: omx-clap-scan (omx-clap-host's) lists the CLAP with
# its id and a version of 1.4.0 or later, and lv2ls and lv2info (lilv) read the LV2 bundle. A scanner that is
# not installed fails the check: a package that was not loaded was not tested.
#
#   load-check.sh [<root>]       root: where the package is installed, default /
set -uo pipefail

root=${1:-/}
root=${root%/}
clap=$root/usr/lib/clap/Surge\ XT.clap
bundle=$root/usr/lib/lv2/Surge\ XT.lv2
id=org.surge-synth-team.surge-xt
uri=https://surge-synthesizer.github.io/lv2/surge-xt
fail=0

for tool in omx-clap-scan lv2ls lv2info; do
    command -v "$tool" >/dev/null || { echo "FAIL $tool is not installed"; fail=1; }
done
[ "$fail" = 0 ] || exit 1

out=$(omx-clap-scan --json "$clap" 2>&1)
rc=$?
version=$(printf '%s' "$out" | sed -n 's/.*"id":"'"$id"'","name":"[^"]*","vendor":"[^"]*","version":"\([0-9.]*\)".*/\1/p' | head -n1)
if [ "$rc" = 0 ] && [ -n "$version" ] && [ "$(printf '%s\n1.4.0\n' "$version" | sort -V | head -n1)" = 1.4.0 ]; then
    echo "PASS omx-clap-scan loads Surge XT.clap, $id $version"
else
    echo "FAIL omx-clap-scan on Surge XT.clap (exit $rc, version '${version}'): ${out:0:300}"
    fail=1
fi

lv2dir=$(mktemp -d)
trap 'rm -rf "$lv2dir"' EXIT
cp -r "$bundle" "$lv2dir/" || { echo "FAIL no LV2 bundle at $bundle"; exit 1; }
if LV2_PATH=$lv2dir lv2ls | grep -qx "$uri"; then echo "PASS lv2ls lists $uri"; else echo "FAIL lv2ls does not list $uri"; fail=1; fi
info=$(LV2_PATH=$lv2dir lv2info "$uri" 2>&1)
if printf '%s' "$info" | grep -q 'Binary:'; then echo "PASS lv2info reads $uri"; else echo "FAIL lv2info cannot read $uri"; fail=1; fi
exit $fail
