#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="$(realpath -- "${0%/*}/..")"
PREFACE="$(< "$BASE/libexec/rules-preface.txt")"
PATHS="$BASE/libexec/frontmatter-path.sed"
MATCH="$BASE/libexec/frontmatter-path-match.sh"

WRAP=(printf -- '<system-reminder>\n%s\n</system-reminder>')

RULES="$BASE/rules"
SESSIONS="$HOME/.local/opt/ai/var/sessions"
SENTINELS="$SESSIONS/$SESSION_ID.rules"

read -r -d '' -- AWK << 'AWK' || true
NR == 1 && /^---$/ {
  in_front = 1
  next
}

in_front && /^---$/ {
  in_front = 0
  next
}

! in_front {
  print
}
AWK

case "$EVENT" in
SessionStart)
  mkdir -p -- "$SENTINELS"
  find "$SENTINELS" -mindepth 1 -delete

  CONTEXT=""

  for RULE in "$RULES"/*.md; do
    GLOBS_RAW="$("$PATHS" "$RULE")"
    readarray -t -- GLOBS <<< "$GLOBS_RAW"
    if ((${#GLOBS[0]})); then
      continue
    fi

    RAW="$(< "$RULE")"

    CONTENT="$(awk "$AWK" <<< "$RAW")"
    CONTEXT+="Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"${CONTENT}"$'\n\n'
  done

  CONTEXT="# agentsMd"$'\n'"$PREFACE"$'\n\n'"$CONTEXT"

  CONTEXT="$("${WRAP[@]}" "$CONTEXT")"
  ;;
PostToolUse)
  FILEPATH="$(jq -e --raw-output '.tool_input.file_path // .tool_input.filePath' <<< "$JSON")"
  CONTEXT=""
  STEMS=()

  mkdir -p -- "$SENTINELS"

  for RULE in "$RULES"/*.md; do
    STEM="${RULE##*/}"
    STEM="${STEM%.md}"

    if [[ -e $SENTINELS/$STEM ]]; then
      continue
    fi

    GLOBS_RAW="$("$PATHS" "$RULE")"
    readarray -t -- GLOBS <<< "$GLOBS_RAW"
    if ((${#GLOBS[0]} == 0)) || ! "$MATCH" "$FILEPATH" "${GLOBS[@]}"; then
      continue
    fi

    RAW="$(< "$RULE")"
    CONTENT="$(awk "$AWK" <<< "$RAW")"
    CONTEXT+="Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"${CONTENT}"$'\n\n'
    STEMS+=("$STEM")
  done

  if ! ((${#STEMS[@]})); then
    exit
  fi

  touch -- "${STEMS[@]/#/$SENTINELS/}"
  CONTEXT="$("${WRAP[@]}" "${CONTEXT%$'\n\n'}")"
  ;;
*)
  set -x
  exit 2
  ;;
esac

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context,
  }
}
JQ
exec -- jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
