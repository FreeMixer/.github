#!/bin/bash
# Build framing-test.c against the libmod-host-protocol pkg-config finds and run it: exit 0 when the library
# carries mod-audio/mod-host#113, 1 when it does not.
#
#   framing-test.sh [<prefix>]
#
# With a prefix, the library installed there (make install-lib PREFIX=<prefix> LIBDIR=<prefix>/lib); without
# one, the installed package. Needs gcc and pkg-config.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -n "${1:-}" ]; then
    prefix=$(readlink -f "$1")
    export PKG_CONFIG_PATH=$prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
    export LD_LIBRARY_PATH=$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# shellcheck disable=SC2046
gcc -std=gnu99 -D_GNU_SOURCE -Wall -Wextra -Werror -o "$work/framing-test" "$here/framing-test.c" \
    $(pkg-config --cflags --libs mod-host-protocol) -lpthread
ldd "$work/framing-test" | grep 'libmod-host-protocol\.so\.0 => /'
timeout 60 "$work/framing-test"
