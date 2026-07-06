#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="${0%/*}/.."
SESSIONS="$HOME/.local/opt/ai/var/sessions"
POST_DIR="$SESSIONS/$SESSION_ID.fmt"

TMP="$(mktemp)"
trap 'rm -fr -- "$TMP"' EXIT
mkdir -p -- "$POST_DIR"

case "$EVENT" in
PostToolUse)
  if ! "$BASE/libexec/parse-hook-paths.sh" <<< "$JSON" > "$TMP"; then
    exit
  fi
  readarray -d '' -t -- PATHNAMES < "$TMP"

  for PATHNAME in "${PATHNAMES[@]}"; do
    HASH="$(b3sum <<< "$PATHNAME")"
    HASH="${HASH%% *}"
    printf -- '%s\0' "$PATHNAME" > "$POST_DIR/$HASH"
  done

  read -r -d '' -- JSON <<- 'JSON' || true
{ "hookSpecificOutput": { "hookEventName": "PostToolUse" } }
JSON
  printf -- '%s' "$JSON"
  ;;
Stop | StopFailure)
  find "$POST_DIR" -mindepth 1 -execdir cat -- '{}' ';' -delete | sort -z --unique > "$TMP"
  SUCC=0
  if CTX="$(xargs -r --null -I % --max-procs=0 -- "$BASE/libexec/fmt-lint.sh" < "$TMP")"; then
    SUCC=1
  fi

  read -r -d '' -- JQ <<- 'JQ' || true
{
  "decision": (if $success == 1 then null else "block" end),
  "reason": (if $success == 1 then null else $reason end)
}
JQ
  jq -e --null-input --argjson success "$SUCC" --arg reason "$CTX" "$JQ"
  ;;
*)
  set -x
  exit 2
  ;;
esac
