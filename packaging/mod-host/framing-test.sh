#!/bin/bash
# Build framing-test.c and commands-test.c against the libmod-host-protocol pkg-config finds and run them: exit 0
# when the library carries mod-audio/mod-host#113 and takes more than 64 commands (the protocol-max-commands patch),
# 1 when it does not, and when the ports it opens by default are reached from any address but 127.0.0.1 (the carried
# bind-address patch).
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
# shellcheck disable=SC2046
if ! gcc -std=gnu99 -D_GNU_SOURCE -Wall -Wextra -Werror -o "$work/commands-test" "$here/commands-test.c" \
    $(pkg-config --cflags --libs mod-host-protocol) -lpthread; then
    echo "FAILED  65 commands registered: commands-test.c does not build against this library"
    exit 1
fi
timeout 60 "$work/commands-test"
# shellcheck disable=SC2046
if ! gcc -std=gnu99 -D_GNU_SOURCE -Wall -Wextra -Werror -o "$work/bind-check" "$here/bind-check.c" \
    $(pkg-config --cflags --libs mod-host-protocol) -lpthread; then
    echo "FAILED  default bind: bind-check.c does not build against this library"
    exit 1
fi
timeout 60 "$work/bind-check"
