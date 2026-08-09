#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="${0%/*}/.."
SESSIONS="$HOME/.local/opt/ai/var/sessions"
POST_DIR="$SESSIONS/$SESSION_ID.fmt"
BATCH="$SESSIONS/$SESSION_ID.post-tool-batch.txt"

TMP="$(mktemp)"
trap 'rm -fr -- "$TMP"' EXIT
mkdir -p -- "$POST_DIR"

case "$EVENT" in
PreToolUse)
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
{ "hookSpecificOutput": { "hookEventName": "PreToolUse" } }
JSON
  printf -- '%s' "$JSON"
  ;;
Stop | StopFailure)
  find "$POST_DIR" -mindepth 1 -execdir cat -- '{}' ';' -delete | sort -z --unique > "$TMP"
  readarray -d '' -t -- PATHNAMES < "$TMP"
  for PATHNAME in "${PATHNAMES[@]}"; do
    if [[ -f $PATHNAME ]]; then
      printf -- '%s\0' "$PATHNAME"
    fi
  done > "$TMP"

  SUCC=false
  if CTX="$(xargs -r --null -I % --max-procs=0 -- ~/.local/libexec/flock.sh % "$BASE/libexec/linters/fmt-lint.sh" % < "$TMP" 2>&1 | tee -- "$BATCH")"; then
    SUCC=true
  else
    rm -fr -- "$BATCH"
  fi

  read -r -d '' -- JQ <<- 'JQ' || true
{
  "decision": (if $success then null else "block" end),
  "reason": (if $success then null else $reason end)
}
JQ
  jq -e --null-input --argjson success "$SUCC" --arg reason "$CTX" "$JQ"
  ;;
PostToolUse)
  trap 'rm -fr -- "$TMP" "$BATCH"' EXIT
  if ! [[ -s $BATCH ]]; then
    exit
  fi

  CONTEXT="$(< "$BATCH")"

  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context,
  }
}
JQ
  jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
  ;;
UserPromptSubmit)
  touch -- "$BATCH"
  CONTEXT="$(< "$BATCH")"
  rm -f -- "$BATCH"

  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context,
  }
}
JQ
  jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
  ;;
*)
  set -x
  exit 2
  ;;
esac
