#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# live-check.sh of the channel-push action against a stub site: a curl that serves a directory and, on a POST to
# the Pages builds endpoint of the REST API, "redeploys" it. It runs with a PATH that has no gh, as in the Debian
# publish container. Arms: the site serves the push at once; the site lags until the Pages build is requested
# again (with the token, by curl); the site never catches up (red, naming the package); with no token the request
# is skipped with a warning and the check goes on until the site turns live; a refused request is a warning, not a
# failure, when the site turns live; an rpm whose live repomd.xml revision is older than the commit's (red), then
# current (green).
#
#   channel-live-check.sh          needs git
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
check=$here/../.github/actions/channel-push/live-check.sh
work=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT; [ -z "${KEEP:-}" ] || echo "$work"
fail() { echo "FAIL: $*" >&2; exit 1; }
pass=0

mkdir -p "$work/bin" "$work/path"
# the tools live-check.sh and the stub take, and no gh
for t in bash git grep sed dirname basename tr wc sleep cat touch; do ln -s "$(command -v "$t")" "$work/path/$t"; done
# curl stub: -fsSL <url> prints the file; -fsI -o /dev/null <url> answers whether it exists. The site is
# $SITE_DIR/live, or $SITE_DIR/next once $SITE_DIR/redeployed exists or after LIVE_AFTER reads. A -X POST
# records the URL and the headers read from stdin in $SITE_DIR/api.log, then redeploys, or fails when
# $SITE_DIR/refuse exists.
cat > "$work/bin/curl" <<'STUB'
#!/bin/bash
url=${@: -1}; url=${url%%\?*}
case " $* " in *" -X POST "*)
    { echo "POST $url $*"; cat; } >> "$SITE_DIR/api.log"
    [ ! -e "$SITE_DIR/refuse" ] || exit 22
    # swallow: the first build request is cancelled by a later push, as in a run of publishes back to back
    if [ -e "$SITE_DIR/swallow" ] && [ ! -e "$SITE_DIR/swallowed" ]; then touch "$SITE_DIR/swallowed"; exit 0; fi
    touch "$SITE_DIR/redeployed"; exit 0 ;;
esac
n=$(( $(cat "$SITE_DIR/reads" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SITE_DIR/reads"
path=${url#https://site.example}
root=$SITE_DIR/live
if [ -d "$SITE_DIR/next" ] && { [ -e "$SITE_DIR/redeployed" ] || [ "$n" -gt "${LIVE_AFTER:-999999}" ]; }; then
    root=$SITE_DIR/next
fi
f=$root$path
case " $* " in *" -fsI "*) [ -e "$f" ] ;; *) [ -e "$f" ] && cat "$f" ;; esac
STUB
chmod +x "$work/bin/curl"
unset GH GITHUB_TOKEN
export CURL=$work/bin/curl POLL=1 REDEPLOY_AFTER=1 LIVE_TIMEOUT=3 GH_TOKEN=test-token GITHUB_API_URL=https://api.example

channel() { # channel <dir>: a channel whose last commit adds one deb and one rpm with repomd revision 200
    local d=$1
    git init -q -b main "$d"
    mkdir -p "$d/deb/debian/trixie/amd64" "$d/rpm/fedora/44/x86_64/repodata"
    printf 'Filename: ./amd64/old_1_amd64.deb\n' > "$d/deb/debian/trixie/Packages"
    echo '<revision>100</revision>' > "$d/rpm/fedora/44/x86_64/repodata/repomd.xml"
    git -C "$d" add -A && git -C "$d" -c user.name=t -c user.email=t@example.org commit -q -m old
    touch "$d/deb/debian/trixie/amd64/new_2_amd64.deb" "$d/rpm/fedora/44/x86_64/new-2.x86_64.rpm"
    printf 'Filename: ./amd64/old_1_amd64.deb\nFilename: ./amd64/new_2_amd64.deb\n' > "$d/deb/debian/trixie/Packages"
    echo '<revision>200</revision>' > "$d/rpm/fedora/44/x86_64/repodata/repomd.xml"
    git -C "$d" add -A && git -C "$d" -c user.name=t -c user.email=t@example.org commit -q -m new
}
site() { # site <dir> <old|new>: what a site directory serves
    mkdir -p "$1"
    if [ "$2" = new ]; then cp -r "$work/ch/." "$1/"; rm -rf "$1/.git"
    else git -C "$work/ch" archive HEAD~1 | tar -x -C "$1"; fi
}
channel "$work/ch"

arm() { # arm <name> <live old|new> <next old|new|none> <what> <expect ok|red> [pattern]
    local name=$1 dir=$work/$1 rc=0
    export SITE_DIR=$dir; mkdir -p "$dir"
    site "$dir/live" "$2"; [ "$3" = none ] || site "$dir/next" "$3"
    PATH=$work/path "$work/path/bash" "$check" "$work/ch" "$4" https://site.example FreeMixer/channel > "$dir/out.log" 2>&1 || rc=$?
    if [ "$5" = ok ]; then [ $rc = 0 ] || { cat "$dir/out.log"; fail "$name: expected green"; }
    else [ $rc != 0 ] || { cat "$dir/out.log"; fail "$name: expected red"; }; grep -q -- "$6" "$dir/out.log" || { cat "$dir/out.log"; fail "$name: no '$6'"; }; fi
    pass=$((pass + 1))
}
arm served-at-once new none deb ok
[ ! -e "$work/served-at-once/api.log" ] || fail "served-at-once asked for a build it did not need"
arm lags-then-redeployed old new deb ok
grep -q '^POST https://api.example/repos/FreeMixer/channel/pages/builds ' "$work/lags-then-redeployed/api.log" \
    || { cat "$work/lags-then-redeployed/out.log"; fail "the lagging site was not redeployed through the REST API"; }
grep -q '^Authorization: Bearer test-token' "$work/lags-then-redeployed/api.log" || fail "the build request carries no token"
! grep -q 'test-token' <(sed -n '/^POST /p' "$work/lags-then-redeployed/api.log") || fail "the token is on the command line"
# the first build request is swallowed; only a second one turns the site live
mkdir -p "$work/cancelled-once"; touch "$work/cancelled-once/swallow"
(export LIVE_TIMEOUT=6; arm cancelled-once old new deb ok)
[ "$(grep -c '^POST .*/pages/builds' "$work/cancelled-once/api.log")" = 2 ] || fail "cancelled-once: the build must be requested a second time, and no more"
arm never-catches-up old old deb red 'new_2_amd64.deb'
[ "$(grep -c '^POST .*/pages/builds' "$work/never-catches-up/api.log")" -ge 2 ] || fail "the build must be requested again while the site lacks the package"
(unset GH_TOKEN; export LIVE_AFTER=2; arm no-token old new deb ok)
grep -q '::warning::no token' "$work/no-token/out.log" || { cat "$work/no-token/out.log"; fail "no-token: no warning"; }
[ ! -e "$work/no-token/api.log" ] || fail "no-token: a build was requested without a token"
pass=$((pass + 1))
mkdir -p "$work/refused"; touch "$work/refused/refuse"
(export LIVE_AFTER=2; arm refused old new deb ok)
grep -q '::warning::the Pages build request was refused' "$work/refused/out.log" || fail "refused: no warning"
pass=$((pass + 1))
arm rpm-old-index old none rpm red 'repomd.xml (revision 100, want 200)'
arm rpm-current new none rpm ok
echo "ok   channel-live-check: $pass arms"
