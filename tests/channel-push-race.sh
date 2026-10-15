#!/bin/bash
# The push of the channel-push action against a remote that loses the race once: another publish lands on the
# branch between our commit and our push. With a rebuild command the action resets to the new tip, assembles
# the tree again, signs a new commit and pushes it: the remote ends with both publishes. Without one (the
# sabotage arm) the same race must fail the step.
#
#   channel-push-race.sh          runs both arms; needs git, gpg, python3 with PyYAML
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
action=$here/../.github/actions/channel-push/action.yml
work=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] || rm -rf "$work"' EXIT; [ -z "${KEEP:-}" ] || echo "$work"
fail() { echo "FAIL: $*" >&2; exit 1; }

python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["runs"]["steps"][0]["run"])' "$action" > "$work/step.sh"

# a signing key for the site commits, in a keyring of its own
export GNUPGHOME=$work/gnupg; mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --quick-gen-key "site <site@example.org>" ed25519 sign never 2>/dev/null
SITE_GPG_KEY=$(gpg --batch --armor --export-secret-keys)
unset GNUPGHOME

# the action sleeps between attempts; the test does not wait
mkdir "$work/bin"; printf '#!/bin/sh\nexit 0\n' > "$work/bin/sleep"; chmod +x "$work/bin/sleep"

arm() { # arm <name> <rebuild command or empty>
    local name=$1 rebuild=$2 dir=$work/$1 rc=0
    mkdir -p "$dir" "$dir/tmp"
    git init -q --bare -b main "$dir/remote.git"
    git clone -q "$dir/remote.git" "$dir/seed" 2>/dev/null
    (cd "$dir/seed" && git -c user.name=t -c user.email=t@example.org commit -q --allow-empty -m seed && git push -q origin HEAD:main)
    # the first push is overtaken: the hook moves the branch to another publish (made beforehand, so its object
    # is in the repository) and the update of the pusher is refused as not a fast-forward
    other=$(cd "$dir/remote.git" && GIT_AUTHOR_NAME=o GIT_AUTHOR_EMAIL=o@example.org GIT_COMMITTER_NAME=o \
        GIT_COMMITTER_EMAIL=o@example.org git commit-tree "main^{tree}" -p main -m "other publish")
    cat > "$dir/remote.git/hooks/pre-receive" <<HOOK
#!/bin/sh
[ -e "$dir/raced" ] && exit 0
touch "$dir/raced"
env -u GIT_QUARANTINE_PATH -u GIT_OBJECT_DIRECTORY -u GIT_ALTERNATE_OBJECT_DIRECTORIES \\
  git --git-dir="$dir/remote.git" update-ref refs/heads/main $other
exit 0
HOOK
    chmod +x "$dir/remote.git/hooks/pre-receive"
    mkdir -p "$dir/run/build" && git clone -q "$dir/remote.git" "$dir/run/build/channel" 2>/dev/null
    mkdir -p "$dir/run/build/channel/rpm" && echo "package one" > "$dir/run/build/channel/rpm/one.txt"
    (cd "$dir/run" && env PATH="$work/bin:$PATH" RUNNER_TEMP="$dir/tmp" GITHUB_REPOSITORY=FreeMixer/t \
        PUBLISH_TOKEN=x SITE_GPG_KEY="$SITE_GPG_KEY" BRANCH=main CHANNEL="$dir/remote.git" TAG=v1 WHAT=rpm \
        REBUILD="$rebuild" ATTEMPTS=3 bash "$work/step.sh" > "$dir/out.log" 2>&1) || rc=$?
    echo "$rc" > "$dir/rc"
}

arm with-retry 'mkdir -p build/channel/rpm && echo "package one" > build/channel/rpm/one.txt'
[ "$(cat "$work/with-retry/rc")" = 0 ] || { cat "$work/with-retry/out.log"; fail "the push did not survive one lost race"; }
files=$(git -C "$work/with-retry/remote.git" ls-tree -r --name-only main | tr '\n' ' ')
[ "$files" = "rpm/one.txt " ] || fail "the remote holds '$files', want rpm/one.txt"
git -C "$work/with-retry/remote.git" log --format=%s main | grep -qx 'other publish' || fail "the other publish was lost"
git -C "$work/with-retry/remote.git" log -1 --format=%G? main | grep -qE '^[GUE]$' || fail "the retried commit is not signed"
grep -q 'lost a race' "$work/with-retry/out.log" || fail "the retry was not announced"

arm no-retry ''
[ "$(cat "$work/no-retry/rc")" != 0 ] || fail "without a rebuild command the lost race passed"
git -C "$work/no-retry/remote.git" ls-tree -r --name-only main | grep -q one.txt && fail "the lost push landed anyway"
echo "ok: the lost race is repeated on the new tip, and fails without the retry"
