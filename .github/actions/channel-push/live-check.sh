#!/bin/bash
# live-check.sh <channel dir> <what> <site url> <channel repo>
#
# After a push, wait until the live site serves what the pushed commit added. GitHub Pages cancels a deployment
# when the next push to the channel arrives, so a commit can be right while the site keeps the tree before it.
#   deb: each added .deb is listed in the live Packages index of its suite
#   rpm: each added .rpm is served, and the live repodata/repomd.xml revision is at least the committed one
# With nothing served after REDEPLOY_AFTER seconds it asks Pages for one more build of the whole tree (the
# latest commit, which carries this one), by curl on the REST API with GH_TOKEN (or GITHUB_TOKEN); with no token
# it skips the request with a warning and keeps waiting, and a refused request is only a warning. After
# LIVE_TIMEOUT seconds it fails, naming what the site still lacks.
# Env: CURL (default curl), GH_TOKEN or GITHUB_TOKEN, GITHUB_API_URL (default https://api.github.com),
# LIVE_TIMEOUT (900), REDEPLOY_AFTER (300), POLL (30).
set -uo pipefail
dir=$1 what=$2 site=${3%/} repo=$4
CURL=${CURL:-curl} api=${GITHUB_API_URL:-https://api.github.com}
LIVE_TIMEOUT=${LIVE_TIMEOUT:-900} REDEPLOY_AFTER=${REDEPLOY_AFTER:-300} POLL=${POLL:-30}

added=$(git -C "$dir" diff --name-only --diff-filter=A HEAD~1 HEAD -- "$what" | grep -E '\.(deb|rpm)$' | grep -v '\.src\.rpm$' || true)
[ -n "$added" ] || { echo "live check: the commit adds no package -- nothing to wait for"; exit 0; }

missing() { # prints what the live site does not serve yet
    local f suite idx want have
    for f in $added; do
        case $f in
            *.deb)
                suite=$(dirname "$(dirname "$f")")
                idx=$($CURL -fsSL "$site/$suite/Packages?live=$RANDOM" 2>/dev/null) || { echo "$suite/Packages"; continue; }
                grep -q "^Filename: .*/$(basename "$f")\$" <<<"$idx" || echo "$f"
                ;;
            *.rpm)
                $CURL -fsI -o /dev/null "$site/$f?live=$RANDOM" 2>/dev/null || echo "$f"
                ;;
        esac
    done
    for idx in $(git -C "$dir" diff --name-only HEAD~1 HEAD -- "$what" | grep 'repodata/repomd.xml$' || true); do
        want=$(sed -n 's:.*<revision>\([0-9]*\)</revision>.*:\1:p' "$dir/$idx")
        have=$($CURL -fsSL "$site/$idx?live=$RANDOM" 2>/dev/null | sed -n 's:.*<revision>\([0-9]*\)</revision>.*:\1:p')
        [ -n "$have" ] && [ "$have" -ge "${want:-0}" ] || echo "$idx (revision ${have:-none}, want ${want:-?})"
    done
}

request_build() { # asks Pages to build the channel again; never fails the check
    local token=${GH_TOKEN:-${GITHUB_TOKEN:-}}
    if [ -z "$token" ]; then
        echo "::warning::no token (GH_TOKEN or GITHUB_TOKEN) -- not asking Pages for another build; still waiting"
        return 0
    fi
    # the token goes in on stdin, not on the command line
    printf 'Authorization: Bearer %s\nAccept: application/vnd.github+json\nX-GitHub-Api-Version: 2022-11-28\n' "$token" |
        $CURL -fsS -o /dev/null -H @- -X POST "$api/repos/$repo/pages/builds" ||
        echo "::warning::the Pages build request was refused"
    return 0
}

start=$SECONDS redeployed=0
while :; do
    lack=$(missing)
    if [ -z "$lack" ]; then
        echo "live check: $site serves every package this publish added ($(wc -w <<<"$added") file(s))"
        exit 0
    fi
    waited=$((SECONDS - start))
    if [ "$redeployed" = 0 ] && [ "$waited" -ge "$REDEPLOY_AFTER" ]; then
        echo "::warning::$site still lacks: $(tr '\n' ' ' <<<"$lack")-- asking Pages to build the channel again"
        request_build
        redeployed=1
    fi
    if [ "$waited" -ge "$LIVE_TIMEOUT" ]; then
        echo "::error::after ${waited}s $site still lacks: $(tr '\n' ' ' <<<"$lack")(the commit is pushed; the Pages deployment is not live)"
        exit 1
    fi
    sleep "$POLL"
done
