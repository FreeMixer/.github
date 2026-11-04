#!/bin/bash
# wave-deps' version bump on throwaway repositories: a tree ahead of its last v<version> tag at that version is built as
# the next minor, written in every place these repositories write it; a tree at its tag, and one whose version already
# moved past its tag, keep their own. And the action's switch: on for a pull request into the wave branch or a push to
# it, off for every other run. Offline.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
build=$here/.github/actions/wave-deps/build.sh
act=$here/.github/actions/wave-deps/action.yml
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

g() { git -C "$1" -c user.name=t -c user.email=t@localhost -c commit.gpgsign=false -c tag.gpgsign=false "${@:2}"; }
mktree() { # <dir> <version>
    local d=$1 v=$2
    mkdir -p "$d/packaging" "$d/debian" "$d/include/x" "$d/share"
    git -C "$d" init -q
    printf 'Name: x\nVersion: %s\nRelease: 1%%{?dist}\n' "$v" > "$d/packaging/x.spec"
    printf 'x (%s) unstable; urgency=medium\n\n  * x\n\n -- t <t@localhost>  Mon, 02 Nov 2026 00:00:00 +0000\n' "$v" > "$d/debian/changelog"
    echo "$v" > "$d/VERSION"
    printf '{\n  "name": "x",\n  "version": "%s",\n  "dependencies": { "y": "%s" }\n}\n' "$v" "$v" > "$d/package.json"
    printf '{\n  "name": "x",\n  "version": "%s",\n  "packages": {\n    "": {\n      "name": "x",\n      "version": "%s"\n    }\n  }\n}\n' "$v" "$v" > "$d/package-lock.json"
    printf '{\n  "version": "%s"\n}\n' "$v" > "$d/share/x.json"
    printf 'VERSION := %s\nOTHER := %s\n' "$v" "$v" > "$d/Makefile"
    IFS=. read -r ma mi pa <<<"$v"
    printf '#define X_VERSION_MAJOR %s\n#define X_VERSION_MINOR %s\n#define X_VERSION_PATCH %s\n' "$ma" "$mi" "$pa" > "$d/include/x/x.h"
    g "$d" add -A && g "$d" commit -qm one && g "$d" tag "v$v"
}
ahead() { echo "$2" >> "$1/README"; g "$1" add README; g "$1" commit -qm "$2"; }

# ahead of v1.4.2 at 1.4.2: built as 1.5.0, everywhere
mktree "$tmp/a" 1.4.2
ahead "$tmp/a" change
out=$(bash "$build" --bump "$tmp/a" 2>/dev/null)
[ "$out" = 1.5.0 ] || fail "ahead of its tag: printed '$out', want 1.5.0"
grep -qx 'Version: 1.5.0' "$tmp/a/packaging/x.spec" || fail spec
head -1 "$tmp/a/debian/changelog" | grep -q '^x (1.5.0) ' || fail debian/changelog
[ "$(cat "$tmp/a/VERSION")" = 1.5.0 ] || fail VERSION
grep -q '^  "version": "1.5.0",' "$tmp/a/package.json" || fail package.json
grep -q '"y": "1.4.2"' "$tmp/a/package.json" || fail "a dependency's version was rewritten"
[ "$(grep -c '"version": "1.5.0"' "$tmp/a/package-lock.json")" = 2 ] || fail package-lock.json
grep -q '^  "version": "1.5.0"' "$tmp/a/share/x.json" || fail "a tracked JSON file's top-level version"
grep -qx 'VERSION := 1.5.0' "$tmp/a/Makefile" || fail Makefile
grep -qx 'OTHER := 1.4.2' "$tmp/a/Makefile" || fail "a Makefile line not VERSION was rewritten"
[ "$(sed -n 's/^#define X_VERSION_[A-Z]* //p' "$tmp/a/include/x/x.h" | paste -sd.)" = 1.5.0 ] || fail header
[ -z "$(git -C "$tmp/a" status --porcelain)" ] || fail "the bump is not committed"
git -C "$tmp/a" log -1 --format=%s | grep -q '^wave-deps: [0-9a-f]* built as 1.5.0' || fail "commit subject"

# at its tag: its own version, nothing committed
mktree "$tmp/b" 2.0.0
before=$(git -C "$tmp/b" rev-parse HEAD)
out=$(bash "$build" --bump "$tmp/b" 2>/dev/null)
[ "$out" = 2.0.0 ] || fail "at its tag: printed '$out', want 2.0.0"
[ "$(git -C "$tmp/b" rev-parse HEAD)" = "$before" ] || fail "at its tag: a commit was made"

# already moved past its tag (0.3.0 over v0.2.0): its own version
mktree "$tmp/c" 0.2.0
sed -i 's/^Version: 0.2.0/Version: 0.3.0/' "$tmp/c/packaging/x.spec"
ahead "$tmp/c" moved
out=$(bash "$build" --bump "$tmp/c" 2>/dev/null)
[ "$out" = 0.3.0 ] || fail "moved past its tag: printed '$out', want 0.3.0"

# the switch: the decide step, read out of the action file, run per event
python3 -I - "$act" "$tmp/decide.sh" <<'PY'
import sys
t = open(sys.argv[1]).read()
body = t.split("    - id: decide\n", 1)[1].split("      run: |\n", 1)[1].split("\n    - ", 1)[0]
open(sys.argv[2], "w").write("".join(l[8:] if l.startswith("        ") else l for l in body.splitlines(True)))
PY
decide() { # <when> <event> <base_ref> <ref> -> active
    : > "$tmp/out"
    GITHUB_OUTPUT=$tmp/out WHEN=$1 EVENT=$2 BASE_REF=$3 REF=$4 BRANCH=dedupe/all REPOS='a b' bash "$tmp/decide.sh" >/dev/null 2>&1 || true
    sed -n 's/^active=//p' "$tmp/out"
}
[ "$(decide auto pull_request dedupe/all refs/pull/1/merge)" = true ] || fail "a pull request into dedupe/all is not a wave run"
[ "$(decide auto push '' refs/heads/dedupe/all)" = true ] || fail "a push to dedupe/all is not a wave run"
[ "$(decide auto pull_request main refs/pull/1/merge)" = false ] || fail "a pull request into main is a wave run"
[ "$(decide auto push '' refs/heads/main)" = false ] || fail "a push to main is a wave run"
[ "$(decide auto push '' refs/tags/v1.0.0)" = false ] || fail "a tag is a wave run"
[ "$(decide auto workflow_dispatch dedupe/all refs/heads/main)" = false ] || fail "a base ref outside a pull request is a wave run"
[ "$(decide always push '' refs/heads/main)" = true ] || fail "when: always"
[ "$(decide never pull_request dedupe/all refs/pull/1/merge)" = false ] || fail "when: never"
[ -z "$(decide sometimes push '' refs/heads/main)" ] || fail "an unknown when was taken"

echo "wave-deps: ok"
