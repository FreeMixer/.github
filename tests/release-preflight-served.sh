#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# release-preflight refuses a release of a version the channel already serves, naming the file: the step is read out
# of the action file and run against a stub curl that answers the repository and its tree. Arms: a new version passes;
# the same rpm version, the same deb version (with and without a revision) and a glob name are refused with the file
# named; another package at that version passes; republish lets it through; a dry run and a branch run never ask;
# a deb release passes over the rpms of its own version (its rpm job published them) and refuses its own debs, and the
# same the other way round.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
act=$here/.github/actions/release-preflight
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
python3 -I - "$act/action.yml" "$tmp/step.sh" <<'PY'
import sys
t = open(sys.argv[1]).read()
body = t.split("      run: |\n", 1)[1]
open(sys.argv[2], "w").write("".join(l[8:] if l.startswith("        ") else l for l in body.splitlines(True)))
PY
mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'STUB'
#!/bin/bash
out= url=${@: -1}
while [ $# -gt 0 ]; do case $1 in -o) out=$2; shift ;; esac; shift; done
echo "$url" >> "$TREE_DIR/asked"
case $url in
  */git/trees/*) cp "$TREE_DIR/tree.json" "$out" ;;
  *) echo '{"permissions":{"push":true},"visibility":"public","default_branch":"main"}' > "$out" ;;
esac
printf 200
STUB
chmod +x "$tmp/bin/curl"
cat > "$tmp/tree.json" <<'J'
{"truncated":false,"tree":[
 {"path":"rpm/fedora/44/x86_64/foo-1.2.3-1.fc44.x86_64.rpm"},
 {"path":"rpm/fedora/44/x86_64/foo-devel-1.4.0-1.fc44.x86_64.rpm"},
 {"path":"deb/debian/trixie/amd64/bar_2.0.0-1_amd64.deb"},
 {"path":"deb/debian/trixie/amd64/libbaz-dev_3.1.0_amd64.deb"},
 {"path":"rpm/fedora/44/x86_64/repodata/repomd.xml"}]}
J
export TREE_DIR=$tmp
run() { # run <publish> <ref-type> <tag> <packages> [republish] [kind]
  PATH=$tmp/bin:$PATH PUBLISH=$1 TARGET=FreeMixer/freemixer.github.io GPG_KEY=k PAGES_TOKEN=t REF=refs/tags/$3 \
    REF_TYPE=$2 REQUIRE_TAG=true TAG=$3 PACKAGES=$4 REPUBLISH=${5:-false} KIND=${6:-} GITHUB_ACTION_PATH=$act bash "$tmp/step.sh" > "$tmp/out" 2>&1
}
run true tag v1.2.4 foo || { cat "$tmp/out"; fail "a new version was refused"; }
run true tag v1.2.3 foo && fail "an rpm version the channel serves passed"
grep -q 'rpm/fedora/44/x86_64/foo-1.2.3-1.fc44.x86_64.rpm' "$tmp/out" || { cat "$tmp/out"; fail "the refusal does not name the rpm"; }
run true tag v2.0.0 bar && fail "a deb version the channel serves passed"
grep -q 'bar_2.0.0-1_amd64.deb' "$tmp/out" || fail "the refusal does not name the deb"
run true tag v3.1.0 'libbaz-*' && fail "a deb without a revision, named by glob, passed"
grep -q 'libbaz-dev_3.1.0_amd64.deb' "$tmp/out" || fail "the glob refusal does not name the deb"
run true tag v1.4.0 foo || fail "another package at that version was refused (foo-devel is not foo)"
run true tag v1.2.3 foo true || fail "republish was refused"
run false tag v1.2.3 foo || fail "a dry run was refused"
: > "$tmp/asked"; run false tag v1.2.3 foo; ! grep -q git/trees "$tmp/asked" || fail "a dry run read the tree"
run true tag v1.2.3 '' || fail "no package list must skip the check"
run true tag v1.2.3 foo false deb || { cat "$tmp/out"; fail "a deb release was refused by the rpms of its own version"; }
run true tag v1.2.3 foo false rpm && fail "an rpm release passed over its own served rpm"
run true tag v2.0.0 bar false rpm || { cat "$tmp/out"; fail "an rpm release was refused by the debs of its own version"; }
run true tag v2.0.0 bar false deb && fail "a deb release passed over its own served deb"
grep -q 'bar_2.0.0-1_amd64.deb' "$tmp/out" || fail "the deb-kind refusal does not name the deb"
echo "ok   release-preflight-served: 13 arms"
