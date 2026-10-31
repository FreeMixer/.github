#!/bin/bash
# The patches of packaging/mod-host apply to the upstream commit of the spec, the tests they bring pass, and the
# installed protocol library carries mod-audio/mod-host#113 and takes 65 commands. Then each fix is taken out again
# and the check that guards it must fail: without the src/ part of #113 or of the protocol-max-commands patch
# framing-test.sh fails, without the src/ part of the bind-address patch its bind check fails, without the src/ part of #112 the
# AddressSanitizer test of #112 (make utils-run) fails. Needs git, gcc, make, python3, pkg-config and libasan.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
carried=$here/../packaging/mod-host
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# the library of <tree>, installed into <tree>/prefix
install_lib() {
    make -s -C "$1" lib && make -s -C "$1" install-lib PREFIX="$1/prefix" LIBDIR="$1/prefix/lib"
}

# expect <exit status> <text the output must hold, or empty> <name> <command>...
expect() {
    local want=$1 text=$2 name=$3
    shift 3
    "$@" > "$work/out" 2>&1
    local got=$?
    if [ "$got" = "$want" ] && { [ -z "$text" ] || grep -qF -- "$text" "$work/out"; }; then
        echo "ok      $name"
    else
        cat "$work/out"
        echo "FAILED  $name: wanted exit $want${text:+ and \"$text\"}, got exit $got"
        failures=$((failures + 1))
    fi
}

"$carried/prepare-source.sh" "$work/all" || exit 1
install_lib "$work/all" || exit 1
expect 0 "" "the tests of #112 and #113, with every patch" make -s -C "$work/all/tests" utils-run socket-run
expect 0 "" "the protocol tests of the library, with every patch" make -s -C "$work/all" test-protocol
expect 0 "all passed" "the bind-address tests of the library, with every patch" make -s -C "$work/all/tests" bind-run
expect 0 "ok      command of exactly 1024 bytes" "the installed library carries #113" "$carried/framing-test.sh" "$work/all/prefix"

"$carried/prepare-source.sh" "$work/without-113" mod-host-113.patch || exit 1
install_lib "$work/without-113" || exit 1
expect 1 "FAILED  command of exactly 1024 bytes" \
    "sabotage: without the fix of #113 the framing test fails" "$carried/framing-test.sh" "$work/without-113/prefix"

"$carried/prepare-source.sh" "$work/without-maxcmd" mod-host-116.patch || exit 1
install_lib "$work/without-maxcmd" || exit 1
expect 1 "FAILED  65 commands registered" \
    "sabotage: without the protocol-max-commands patch the library refuses the 65th command" \
    "$carried/framing-test.sh" "$work/without-maxcmd/prefix"
"$carried/prepare-source.sh" "$work/without-bind" mod-host-bind.patch || exit 1
install_lib "$work/without-bind" || exit 1
expect 1 "FAILED  default bind" \
    "sabotage: without the bind-address patch the library listens on every address" \
    "$carried/framing-test.sh" "$work/without-bind/prefix"
"$carried/prepare-source.sh" "$work/without-112" mod-host-112.patch || exit 1
expect 2 "AddressSanitizer: heap-buffer-overflow" \
    "sabotage: without the fix of #112 its AddressSanitizer test fails" make -s -C "$work/without-112/tests" utils-run

if [ "$failures" != 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
