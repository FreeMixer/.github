#!/bin/bash
# live-check.sh of the channel-push action against a stub site: a curl that serves a directory and a gh that
# "redeploys" it. Arms: the site serves the push at once; the site lags until the Pages build is requested
# again; the site never catches up (red, naming the package); an rpm whose live repomd.xml revision is older
# than the commit's (red), then current (green).
#
#   channel-live-check.sh          needs git
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
check=$here/../.github/actions/channel-push/live-check.sh
work=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT; [ -z "${KEEP:-}" ] || echo "$work"
fail() { echo "FAIL: $*" >&2; exit 1; }
pass=0

mkdir -p "$work/bin"
# curl stub: -fsSL <url> prints the file; -fsI -o /dev/null <url> answers whether it exists. The site is
# $SITE_DIR/live, or $SITE_DIR/next once $SITE_DIR/redeployed exists.
cat > "$work/bin/curl" <<'STUB'
#!/bin/bash
url=${@: -1}; url=${url%%\?*}; path=${url#https://site.example}
root=$SITE_DIR/live; [ -e "$SITE_DIR/redeployed" ] && [ -d "$SITE_DIR/next" ] && root=$SITE_DIR/next
f=$root$path
case " $* " in *" -fsI "*) [ -e "$f" ] ;; *) [ -e "$f" ] && cat "$f" ;; esac
STUB
cat > "$work/bin/gh" <<'STUB'
#!/bin/bash
echo "gh $*" >> "$SITE_DIR/gh.log"; touch "$SITE_DIR/redeployed"
STUB
chmod +x "$work/bin/curl" "$work/bin/gh"
export CURL=$work/bin/curl GH=$work/bin/gh POLL=1 REDEPLOY_AFTER=1 LIVE_TIMEOUT=3

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
    bash "$check" "$work/ch" "$4" https://site.example FreeMixer/channel > "$dir/out.log" 2>&1 || rc=$?
    if [ "$5" = ok ]; then [ $rc = 0 ] || { cat "$dir/out.log"; fail "$name: expected green"; }
    else [ $rc != 0 ] || { cat "$dir/out.log"; fail "$name: expected red"; }; grep -q -- "$6" "$dir/out.log" || { cat "$dir/out.log"; fail "$name: no '$6'"; }; fi
    pass=$((pass + 1))
}
arm served-at-once new none deb ok
[ ! -e "$work/served-at-once/gh.log" ] || fail "served-at-once asked for a build it did not need"
arm lags-then-redeployed old new deb ok
grep -q 'pages/builds' "$work/lags-then-redeployed/gh.log" || fail "the lagging site was not redeployed"
arm never-catches-up old old deb red 'new_2_amd64.deb'
[ "$(grep -c pages/builds "$work/never-catches-up/gh.log")" = 1 ] || fail "the build must be requested once"
arm rpm-old-index old none rpm red 'repomd.xml (revision 100, want 200)'
arm rpm-current new none rpm ok
echo "ok   channel-live-check: $pass arms"
