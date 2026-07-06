#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="$(realpath -- "${0%/*}/..")"
SESSIONS="$HOME/.local/opt/ai/var/sessions"
POST_DIR="$SESSIONS/$SESSION_ID.fmt"

CONTEXT=()

case "$EVENT" in
PostToolUse)
  TMP="$(mktemp)"
  trap 'rm -fr -- "$TMP"' EXIT

  if ! "$BASE/libexec/parse-hook-paths.sh" <<< "$JSON" > "$TMP"; then
    exit
  fi
  readarray -d '' -t -- PATHNAMES < "$TMP"

  mkdir -p -- "$POST_DIR"

  for PATHNAME in "${PATHNAMES[@]}"; do
    HASH="$(b3sum <<< "$PATHNAME")"
    HASH="${HASH%% *}"
    printf -- '%s\0' "$PATHNAME" > "$POST_DIR/$HASH"
  done
  ;;
Stop | StopFailure)
  if ! [[ -d $POST_DIR ]]; then
    exit
  fi

  shopt -u failglob
  PATHS="$(cat -- /dev/null "$POST_DIR"/*)"
  find "$POST_DIR" -mindepth 1 -delete

  if [[ -z $PATHS ]]; then
    exit
  fi

  readarray -d '' -t -- PATHNAMES < <(printf -- '%s' "$PATHS")

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

if ! ((${#CONTEXT[@]})); then
  exit
fi

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
