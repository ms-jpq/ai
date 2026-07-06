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
  (
    shopt -u failglob
    cat -- /dev/null "$POST_DIR"/*
  ) > "$TMP"
  readarray -d '' -t -- PATHNAMES < "$TMP"
  find "$POST_DIR" -mindepth 1 -delete

  for PATHNAME in "${PATHNAMES[@]}"; do
    if ! [[ -f $PATHNAME ]]; then
      continue
    fi

    # shellcheck disable=SC2154,SC2094
    if FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$PATHNAME" < "$PATHNAME" 2>&1)"; then
      sponge -- "$PATHNAME" <<< "$FMT"
    fi

    case "$PATHNAME" in
    *.sh | *.bash)
      if command -v -- shellcheck > /dev/null; then
        if ! SC_OUT="$(shellcheck --shell=bash -- "$PATHNAME" 2>&1)"; then
          CONTEXT+=("shellcheck($PATHNAME): $SC_OUT")
        fi
      fi
      ;;
    *)
      ;;
    esac
  done
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
