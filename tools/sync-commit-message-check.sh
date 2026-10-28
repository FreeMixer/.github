#!/bin/bash
# sync-commit-message-check.sh OPS_DIR: copy the checker and its pattern list from the ops tree into the commit-message-check action.
# The list is edited in ops only; this copy is generated.
set -euo pipefail
ops=${1:?usage: sync-commit-message-check.sh OPS_DIR}
dst=$(dirname "$0")/../.github/actions/commit-message-check
for f in commit-message-check.sh commit-message-patterns.json; do
  cp "$ops/$f" "$dst/$f"
done
