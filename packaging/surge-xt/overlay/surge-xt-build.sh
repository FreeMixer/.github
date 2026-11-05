#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# The one build of Surge XT that the RPM (packaging/surge-xt/surge-xt.spec) and the DEB (actions/deb-deps/surge-xt)
# both run, so the two carry the same code built the same way.
#
#   surge-xt-build.sh build <source dir> <build dir>
#   surge-xt-build.sh install <source dir> <build dir> <destdir>
#
# Upstream builds with -Werror (SURGE_SKIP_WERROR is its switch): the compiler here is newer than its CI's, and a new
# warning in a vendored library is not a reason to refuse the package.
# The CLAP and the LV2 are the only formats built: the VST3, the standalone application and Surge XT Effects are not.
# The LV2 is JUCE 8's own wrapper, the JUCE the repository carries as a submodule, not the branch of the JUCE LV2
# porting project that upstream's scripts/installer_linux/build-lv2 fetches. Installed to the FHS places hosts look
# in, /usr/lib/clap and /usr/lib/lv2, never to /usr/local or to a multiarch directory, and the factory data to
# /usr/share/surge-xt, where upstream's own Linux installer puts it.
set -euo pipefail

verb=${1:?usage: surge-xt-build.sh build|install <source dir> <build dir> [<destdir>]}
src=$(readlink -m "${2:?source dir}")
bld=$(readlink -m "${3:?build dir}")

case "$verb" in
build)
    cmake -GNinja -S "$src" -B "$bld" -DCMAKE_BUILD_TYPE=Release -DSURGE_BUILD_LV2=ON -DSURGE_BUILD_CLAP=ON \
        -DSURGE_SKIP_WERROR=TRUE -DSURGE_BUILD_TESTRUNNER=OFF -DSURGE_SKIP_STANDALONE=TRUE -DSURGE_COPY_TO_PRODUCTS=OFF
    cmake --build "$bld" --target surge-xt_CLAP surge-xt_LV2 ${SURGE_JOBS:+--parallel "$SURGE_JOBS"}
    ;;
install)
    dest=$(readlink -m "${4:?destdir}")
    art=$bld/src/surge-xt/surge-xt_artefacts/Release
    clap=$(find "$art" -maxdepth 2 -name 'Surge XT.clap' | head -n1)
    lv2=$(find "$art" -maxdepth 2 -name 'Surge XT.lv2' -type d | head -n1)
    [ -n "$clap" ] && [ -n "$lv2" ] || { echo "the build holds no CLAP or no LV2 under $art" >&2; exit 1; }
    install -d "$dest/usr/lib/clap" "$dest/usr/lib/lv2" "$dest/usr/share/surge-xt"
    install -m 0755 "$clap" "$dest/usr/lib/clap/Surge XT.clap"
    cp -r "$lv2" "$dest/usr/lib/lv2/"
    find "$dest/usr/lib/lv2" -type f -name '*.so' -exec chmod 0755 {} +
    cp -r "$src/resources/data/." "$dest/usr/share/surge-xt/"
    ;;
*)
    echo "unknown verb $verb" >&2
    exit 1
    ;;
esac
