#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

BASE="${0%/*}"
ROOT="$BASE/../../.."
exec -- "$ROOT/.venv/bin/python3" "$BASE/langfuse-hook.py" >> langfuse.log 2>&1
