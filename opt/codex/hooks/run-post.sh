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
CONTEXT=()

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
  ;;
Stop | StopFailure)
  find "$POST_DIR" -mindepth 1 -execdir cat -- '{}' + -delete | sort -z --unique > "$TMP"
  CONTEXT+=("$(xargs -r --null -I % --max-procs=0 -- "$BASE/libexec/fmt-lint.sh" < "$TMP" || true)")
  ;;
*)
  set -x
  exit 2
  ;;
esac

printf -v CONTEXT_TEXT -- '%s\n\n' "${CONTEXT[@]}"
printf -v CONTEXT_TEXT -- '%s' "${CONTEXT_TEXT%$'\n\n'}"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context
  }
}
JQ
jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT_TEXT" "$JQ"
