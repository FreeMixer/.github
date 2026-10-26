#!/bin/bash
# sync-ai-trace.sh OPS_DIR: copy the checker and its pattern list from the ops tree into the ai-trace-check action.
# The list is edited in ops only; this copy is generated.
set -euo pipefail
ops=${1:?usage: sync-ai-trace.sh OPS_DIR}
dst=$(dirname "$0")/../.github/actions/ai-trace-check
for f in ai-trace-commit-check.sh ai-trace-patterns.json; do
  cp "$ops/$f" "$dst/$f"
done
