#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# The Surge XT package: the spec builds the commit pins.txt pins, at 1.4.0 or later and with no patch; the RPM and the
# DEB install the CLAP to /usr/lib/clap and the LV2 to /usr/lib/lv2 and nothing to /usr/local; the load check passes
# for a scanner that finds Surge XT 1.4.0 and fails for one that finds 1.3.4, for one that finds no plugin and for a
# scanner that is missing. Then the floor of the load check is taken out and the 1.3.4 case must fail the test.
# Needs bash and coreutils; the scanners are stand-ins in a temporary PATH.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pkg=$here/packaging/surge-xt
deb=$here/.github/actions/deb-deps/surge-xt
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

ok() { echo "ok      $1"; }
bad() { echo "FAILED  $1"; failures=$((failures + 1)); }
check() { local name=$1; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }

pin=$(sed -n 's/^surge-xt [^ ]* //p' "$here/.github/pins.txt")
commit=$(sed -n 's/^%global commit0 *//p' "$pkg/surge-xt.spec")
version=$(sed -n 's/^Version: *//p' "$pkg/surge-xt.spec")
check "the spec builds the pinned commit" test -n "$pin" -a "$pin" = "$commit"
check "the DEB changelog names the pinned commit" grep -q "\.${pin:0:7}-" "$deb/changelog"
check "the version is 1.4.0 or later" test "$(printf '%s\n1.4.0\n' "$version" | sort -V | head -n1)" = 1.4.0
check "no patch is carried" test -z "$(ls "$pkg"/*.patch "$pkg"/overlay/*.patch 2>/dev/null)" -a -z "$(grep -i '^Patch' "$pkg/surge-xt.spec")"
check "the RPM installs the CLAP to /usr/lib/clap" grep -qx '"/usr/lib/clap/Surge XT.clap"' "$pkg/surge-xt.spec"
check "the RPM installs the LV2 to /usr/lib/lv2" grep -qx '"/usr/lib/lv2/Surge XT.lv2/"' "$pkg/surge-xt.spec"
check "the DEB installs the CLAP to /usr/lib/clap" grep -qx 'usr/lib/clap/\*.clap' "$deb/surge-xt-clap.install"
check "the DEB installs the LV2 to /usr/lib/lv2" grep -qx 'usr/lib/lv2/\*.lv2' "$deb/surge-xt-lv2.install"
check "nothing is installed to /usr/local or a multiarch directory" \
    test -z "$(grep -n '/usr/local\|_libdir\|multiarch\|DEB_HOST' "$pkg/overlay/surge-xt-build.sh" "$deb/rules" "$deb"/*.install | grep -v ':[0-9]*:#')"

# a scanner that prints <json> and exits <rc>
fake_scanner() { # dir json rc
    mkdir -p "$1"
    printf '#!/bin/sh\nprintf %%s '"'"'%s'"'"'\nexit %s\n' "$2" "$3" > "$1/omx-clap-scan"
    chmod +x "$1/omx-clap-scan"
}
json() { printf '{"scanner":"omx-clap-scan","files":[{"path":"x","plugins":[{"id":"org.surge-synth-team.surge-xt","name":"Surge XT","vendor":"Surge Synth Team","version":"%s","params":[]}]}]}' "$1"; }

# lilv's tools, stand-ins that know the bundle
mkdir -p "$work/lilv"
printf '#!/bin/sh\necho https://surge-synthesizer.github.io/lv2/surge-xt\n' > "$work/lilv/lv2ls"
printf '#!/bin/sh\necho "Binary: file:///x/libSurge%%20XT.so"\n' > "$work/lilv/lv2info"
chmod +x "$work/lilv/lv2ls" "$work/lilv/lv2info"
mkdir -p "$work/root/usr/lib/clap" "$work/root/usr/lib/lv2/Surge XT.lv2"

# run_check <checker> <scanner dir or none>: the exit status of the load check with only the stand-ins on PATH
run_check() {
    local tools=$work/path
    rm -rf "$tools"; mkdir -p "$tools"
    cp "$work"/lilv/* "$tools/"
    [ "$2" = none ] || cp "$2"/omx-clap-scan "$tools/"
    for t in bash sh sed sort head grep cp mktemp rm printf cat dirname; do ln -sf "$(command -v $t)" "$tools/$t"; done
    PATH=$tools "$1" "$work/root" > "$work/out" 2>&1
}

fake_scanner "$work/s140" "$(json 1.4.0)" 0
fake_scanner "$work/s134" "$(json 1.3.4)" 0
fake_scanner "$work/sempty" '{"files":[]}' 0
fake_scanner "$work/sfail" "$(json 1.4.0)" 1
check "the load check passes for Surge XT 1.4.0" run_check "$pkg/load-check.sh" "$work/s140"
if run_check "$pkg/load-check.sh" "$work/s134"; then bad "the load check fails for 1.3.4"; else ok "the load check fails for 1.3.4"; fi
if run_check "$pkg/load-check.sh" "$work/sempty"; then bad "the load check fails when no plugin is found"; else ok "the load check fails when no plugin is found"; fi
if run_check "$pkg/load-check.sh" "$work/sfail"; then bad "the load check fails when the scanner fails"; else ok "the load check fails when the scanner fails"; fi
if run_check "$pkg/load-check.sh" none; then bad "the load check fails when omx-clap-scan is missing"; else ok "the load check fails when omx-clap-scan is missing"; fi

# sabotage: the floor out of the load check, and 1.3.4 must pass it, which the test above refuses
sed 's/= 1.4.0 \]/= 0.0.0 ]/; s/1\.4\.0\\n/0.0.0\\n/' "$pkg/load-check.sh" > "$work/sabotaged.sh"
chmod +x "$work/sabotaged.sh"
if run_check "$work/sabotaged.sh" "$work/s134"; then ok "sabotage: without the 1.4.0 floor a 1.3.4 build passes, so the test above is red"; else bad "sabotage: the floor edit did not take"; fi

[ "$failures" = 0 ] || { echo "$failures failed"; exit 1; }
echo "all passed"
