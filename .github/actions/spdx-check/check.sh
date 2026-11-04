#!/usr/bin/env bash
# spdx-check: every tracked file a comment can be written in opens with its licence and its copyright.
#
#   check.sh [ROOT]        the check, over every file ROOT (default: the current directory) tracks
#   check.sh --self-test   each sabotage must go red
#
# The rule is about the format, and there is no list of files. A file names its licence (an SPDX-License-Identifier
# line) and its copyright (a Copyright line) in its first 20 lines, unless its format has no comment syntax to write
# them in; no_comment_syntax below says which those are. A text format nobody has named needs the lines, so a new kind
# of file is red until it carries them or its format is named here.
#
# Reading no file is a failure: a git that cannot read the tree (a container's checkout another user owns) hands a
# loop an empty list, and an empty list has nothing wrong with it.
set -euo pipefail

HEAD_LINES=20

# True when the file's format has nowhere to write a comment. Arguments: <path> <absolute path>.
no_comment_syntax() {
  local base=${1##*/}
  case "$1" in
    debian/changelog|debian/source/format) return 0 ;;   # dpkg parses every line of both
    debian/copyright) return 0 ;;                        # the licence statement itself, in a format with no comments
    fuzz/corpus/*|*/fuzz/corpus/*) return 0 ;;           # raw input to a harness: every byte is the input
  esac
  case "$base" in
    LICENSE|LICENSE.*|LICENCE|LICENCE.*|COPYING|COPYING.*) return 0 ;;   # the licence text itself
    *.json|*.jsonl) return 0 ;;                                          # JSON has no comments
    *.txt|*.tsv|*.csv) return 0 ;;                                       # plain text and tables: every line is data
    *.sha256) return 0 ;;                                                # digests, one per line
  esac
  # binary: a NUL in the first 8000 bytes, the test git itself uses. An image, a font, a fuzz seed.
  [ -n "$(head -c 8000 -- "$2" | LC_ALL=C tr -dc '\000' | head -c 1 | LC_ALL=C tr '\000' x)" ]
}

check() { # <absolute root>
  local root=$1 files f head read=0 carrying=0 formatless=0 bad=0
  # a CI container checks the tree out as another user, and git refuses a tree it does not own unless told
  files=$(git -c safe.directory="$root" -C "$root" ls-files) || { echo "spdx-check: git lists no file in $root" >&2; return 1; }
  [ -n "$files" ] || { echo "spdx-check: git lists no file in $root" >&2; return 1; }
  while IFS= read -r f; do
    read=$((read + 1))
    # a symbolic link or an empty file has no text to write a line in
    if [ -L "$root/$f" ] || [ ! -s "$root/$f" ]; then formatless=$((formatless + 1)); continue; fi
    head=$(head -n "$HEAD_LINES" -- "$root/$f" | LC_ALL=C tr -d '\000')
    if grep -qE 'SPDX-License-Identifier: [A-Za-z0-9.+-]' <<<"$head" && grep -qE 'Copyright (\(C\)|©) ' <<<"$head"; then
      carrying=$((carrying + 1)); continue
    fi
    if no_comment_syntax "$f" "$root/$f"; then formatless=$((formatless + 1)); continue; fi
    echo "spdx-check: $f has no SPDX-License-Identifier and Copyright line in its first $HEAD_LINES lines" >&2
    bad=1
  done <<<"$files"
  [ "$bad" = 0 ] || return 1
  # a tree where nothing needed the lines is a tree this check did not read
  [ "$carrying" -gt 0 ] || { echo "spdx-check: $read files read and none carries the lines" >&2; return 1; }
  echo "spdx-check: $read tracked files read, $carrying carry the lines, $formatless have no comment syntax to carry them in"
}

if [ "${1:-}" = --self-test ]; then
  t=$(mktemp -d); trap 'rm -rf "$t"' EXIT; fail=0
  H='// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 A Name <a@example.invalid>'
  mk() { # a clean tree, one file of each kind the rule names
    rm -rf "$t/r"; git init -q "$t/r"; mkdir -p "$t/r/src" "$t/r/debian/source" "$t/r/seeds"
    printf '%s\nint x;\n' "$H" > "$t/r/src/x.c"
    printf '{"a": 1}\n' > "$t/r/src/x.json"
    printf '1 bell:630\n' > "$t/r/src/golden.txt"
    printf 'a\tb\n' > "$t/r/src/t.tsv"
    printf 'GNU GENERAL PUBLIC LICENSE\n' > "$t/r/LICENSE"
    printf 'x (1) unstable; urgency=medium\n' > "$t/r/debian/changelog"
    printf '3.0 (native)\n' > "$t/r/debian/source/format"
    printf 'Format: https://example.invalid/\n' > "$t/r/debian/copyright"
    printf '\000\001\002rate' > "$t/r/seeds/zero-rate"
    mkdir -p "$t/r/fuzz/corpus/eq"; printf '#' > "$t/r/fuzz/corpus/eq/one-byte-seed"
    : > "$t/r/src/empty"
    ln -s x.c "$t/r/src/link.c"
  }
  green() { # <name>
    git -C "$t/r" add -A
    if check "$t/r" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1: red"; check "$t/r" 2>&1 | sed 's/^/     /'; fail=1; fi
  }
  red() { # <name> <text the failure names>
    git -C "$t/r" add -A
    local out rc=0
    out=$(check "$t/r" 2>&1) || rc=$?
    if [ "$rc" = 0 ]; then echo "FAIL $1: stays green"; fail=1
    elif ! grep -qF -- "$2" <<<"$out"; then echo "FAIL $1: red for another reason: $out"; fail=1
    else echo "ok   $1"; fi
  }
  mk; green "a clean tree, every format the rule names, is green"
  mk; printf 'int y;\n' > "$t/r/src/y.c"; red "a source without the lines is red" 'src/y.c'
  mk; printf '// SPDX-License-Identifier: MIT\nint y;\n' > "$t/r/src/y.c"; red "a licence without a copyright is red" 'src/y.c'
  mk; printf '// Copyright (C) 2026 A\nint y;\n' > "$t/r/src/y.c"; red "a copyright without a licence is red" 'src/y.c'
  mk; { seq 1 "$HEAD_LINES" | sed 's/^/\/\/ /'; printf '%s\n' "$H"; } > "$t/r/src/y.c"; red "the lines below the first $HEAD_LINES are red" 'src/y.c'
  mk; printf 'text of an unnamed format\n' > "$t/r/src/SOURCES"; red "text with no extension is red" 'src/SOURCES'
  mk; printf 'fn main() {}\n' > "$t/r/src/y.rs"; red "an extension nobody named is red" 'src/y.rs'
  mk; printf 'a: 1\n' > "$t/r/src/y.yml"; red "a format with comments is red without them" 'src/y.yml'
  mk; printf 'LICENSE\n' > "$t/r/debian/control"; red "debian/control has comments and is red without them" 'debian/control'
  mk; printf 'not a licence\n' > "$t/r/src/LICENSES.c"; red "a name that only starts like a licence is red" 'src/LICENSES.c'
  mk; printf 'x%.0s' $(seq 1 9000) > "$t/r/src/y.c"; printf '\000' >> "$t/r/src/y.c"; red "a NUL past the first 8000 bytes is text, and red" 'src/y.c'
  mk; printf 'Source: x\n' > "$t/r/src/control.txt.c"; red "only the last extension names the format" 'src/control.txt.c'
  mk; mkdir -p "$t/r/tools/corpus"; printf 'text\n' > "$t/r/tools/corpus/a"; red "a corpus outside fuzz/ is red" 'tools/corpus/a'
  # reading nothing is red, whichever way nothing came to be read
  rm -rf "$t/r"; git init -q "$t/r"; red "an empty tree is red" 'git lists no file'
  rm -rf "$t/r"; mkdir -p "$t/r"; if check "$t/r" >/dev/null 2>&1; then echo "FAIL a directory git cannot read stays green"; fail=1; else echo "ok   a directory git cannot read is red"; fi
  rm -rf "$t/r"; git init -q "$t/r"; printf '{}\n' > "$t/r/a.json"; red "a tree where nothing carries the lines is red" 'none carries the lines'
  # a checkout another user owns is still read: a git that refused it would be the zero-file failure above
  mk; printf 'int y;\n' > "$t/r/src/y.c"; git -C "$t/r" add -A
  if out=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TEST_ASSUME_DIFFERENT_OWNER=1 check "$t/r" 2>&1); then echo "FAIL a checkout another user owns is not read: $out"; fail=1
  elif grep -qF 'src/y.c' <<<"$out"; then echo "ok   a checkout another user owns is read"; else echo "FAIL another user's checkout, red for another reason: $out"; fail=1; fi
  # sabotage: the check without its rules. Each arm below must change the verdict, or the arm above proved nothing.
  sed -E 's/^( *)files=\$\(git .*$/\1files=$(git -c safe.directory="$root" -C "$root" ls-files) || true/; s/^( *)\[ -n "\$files" \] \|\| .*$/\1[ -n "$files" ] || { echo "spdx-check: 0 files read"; return 0; }/' "${BASH_SOURCE[0]}" > "$t/sab-zero.sh"
  rm -rf "$t/s"; git init -q "$t/s"
  if bash "$t/sab-zero.sh" "$t/s" >/dev/null 2>&1; then echo "ok   sabotage: without the zero-file rule an empty tree passes"; else echo "FAIL sabotage: the zero-file rule is not what catches an empty tree"; fail=1; fi
  sed -E 's/^( *)if no_comment_syntax .*$/\1if true; then formatless=$((formatless + 1)); continue; fi/' "${BASH_SOURCE[0]}" > "$t/sab-all.sh"
  git -C "$t/s" init -q; printf '%s\nint x;\n' "$H" > "$t/s/x.c"; printf 'int y;\n' > "$t/s/y.c"; git -C "$t/s" add -A
  if bash "$t/sab-all.sh" "$t/s" >/dev/null 2>&1; then echo "ok   sabotage: with every format comment-free a bare source passes"; else echo "FAIL sabotage: the format rule is not what catches a bare source"; fail=1; fi
  sed -E 's/^( *)if no_comment_syntax .*$/\1if false; then :; fi/' "${BASH_SOURCE[0]}" > "$t/sab-none.sh"
  mk; git -C "$t/r" add -A
  if bash "$t/sab-none.sh" "$t/r" >/dev/null 2>&1; then echo "FAIL sabotage: with no comment-free format the clean tree stays green"; fail=1; else echo "ok   sabotage: with no comment-free format the clean tree is red"; fi
  [ "$fail" = 0 ] || exit 1
  echo "spdx-check self-test: every sabotage red"
  exit 0
fi

root=${1:-.}
check "$(cd "$root" && pwd)"
