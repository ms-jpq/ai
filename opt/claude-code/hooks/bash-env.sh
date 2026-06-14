#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
if [[ -v CLAUDE_ENV_FILE ]]; then
  printf -- 'export -- __CC_SESSION_ID=%s\n' "${SESSION_ID@Q}" >> "$CLAUDE_ENV_FILE"
fi
