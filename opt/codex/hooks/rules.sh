#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"

BASE="$(realpath -- "${0%/*}/..")"
PREFACE="$(< "$BASE/libexec/rules-preface.txt")"

WRAP=(printf -- '<system-reminder>\n%s\n</system-reminder>')

RULES="$BASE/rules"

case "$EVENT" in
SessionStart)
  CONTEXT=""

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

  for RULE in "$RULES"/*.md; do
    RAW="$(< "$RULE")"

    CONTENT="$(awk "$AWK" <<< "$RAW")"
    CONTEXT+="Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"${CONTENT}"$'\n\n'
  done

  CONTEXT="# agentsMd"$'\n'"$PREFACE"$'\n\n'"$CONTEXT"

  CONTEXT="$("${WRAP[@]}" "$CONTEXT")"

  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $context,
  }
}
JQ
  exec -- jq -e --null-input --arg context "$CONTEXT" "$JQ"
  ;;
PostToolUse)
  ;;
*)
  set -x
  exit 2
  ;;
esac
