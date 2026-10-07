#!/bin/bash
# The Debian half of the channel publish: a package built from a debian/changelog carries it, publish-tree.sh
# serves it next to the apt index, and `apt changelog` shows it for a version that is not installed. Needs a
# Debian container with dpkg-dev, debhelper, apt-utils and python3.
#
#   tests/deb-changelog.sh
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'kill ${http:-0} 2>/dev/null || true; rm -rf "$work"' EXIT
cd "$work"

mkdir -p demo-1.0/debian/source debs
cd demo-1.0
echo '3.0 (native)' > debian/source/format
cat > debian/control <<'C'
Source: demo
Section: sound
Priority: optional
Maintainer: Pau Aliagas <linuxnow@gmail.com>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.7.0

Package: demo
Architecture: all
Description: a demo for the channel
 Demo package.
C
printf '#!/usr/bin/make -f\n%%:\n\tdh $@\n' > debian/rules
chmod +x debian/rules
cat > debian/changelog <<'C'
demo (1.0) unstable; urgency=medium

  * Quieter start, and a fix for the long-session slowdown.

 -- Pau Aliagas <linuxnow@gmail.com>  Wed, 07 Oct 2026 12:00:00 +0000
C
echo data > data
echo 'data usr/share/demo/' > debian/demo.install
dpkg-buildpackage -b -uc -us >/dev/null 2>&1
cd ..
mkdir debs/trixie
cp demo_1.0_all.deb debs/trixie/

dpkg-deb -c debs/trixie/demo_1.0_all.deb | grep -E 'usr/share/doc/demo/changelog(\.Debian)?\.gz'
echo "ok   the package carries its changelog"

CHANGELOGS_URL=http://127.0.0.1:8099/changelogs "$here/.github/actions/publish-debs/publish-tree.sh" "$work/tree" debs
grep -q '^Changelogs: http://127.0.0.1:8099/changelogs/@CHANGEPATH@_changelog$' "$work/tree/debian/trixie/Release"
grep -q 'Quieter start' "$work/tree/changelogs/d/demo/demo_1.0_changelog"
echo "ok   the tree serves the changelog and the Release file names it"

(cd "$work/tree" && python3 -m http.server 8099 --bind 127.0.0.1 >/dev/null 2>&1) &
http=$!
sleep 1
echo "deb [trusted=yes] http://127.0.0.1:8099/debian/trixie ./" > /etc/apt/sources.list.d/channel.list
apt-get update
out=$(apt changelog demo 2>&1 || true)
echo "$out"
grep -q 'Quieter start, and a fix for the long-session slowdown' <<<"$out"
echo "deb changelog tests: all passed"
