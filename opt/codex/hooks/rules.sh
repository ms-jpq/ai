#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="$(realpath -- "${0%/*}/..")"
PATHS="$BASE/libexec/frontmatter-path.sed"

RULES="$BASE/rules"
SENTINELS="$HOME/.local/opt/ai/var/sessions/$SESSION_ID.rules"

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

  PREFACE="$(< "$BASE/libexec/rules-preface.txt")"
  CONTEXT=("# agentsMd"$'\n'"$PREFACE")

  for RULE in "$RULES"/*.md; do
    if "$PATHS" "$RULE" | grep --quiet -e .; then
      continue
    fi

    CONTENT="$(awk "$AWK" < "$RULE")"
    CONTEXT+=("Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"$CONTENT")
  done
  ;;
PostToolUse)
  TMP="$(mktemp)"
  trap 'rm -fr -- "$TMP"' EXIT

  jq -e --raw-output0 '[.tool_input, .tool_response] | .. | strings | ., scan("[^\\s\"'\''`|;&()<>]+")' <<< "$JSON" > "$TMP"
  readarray -d '' -t -- PATHNAMES < "$TMP"

  mkdir -p -- "$SENTINELS"

  CONTEXT=()
  for RULE in "$RULES"/*.md; do
    STEM="${RULE##*/}"
    STEM="${STEM%.md}"

    if [[ -e $SENTINELS/$STEM ]] || ! GB="$("$PATHS" "$RULE" | grep -e .)"; then
      continue
    fi
    readarray -t -- GLOBS < <(printf -- '%s' "$GB")

    MATCHED=0
    for PATHNAME in "${PATHNAMES[@]}"; do
      if "$BASE/libexec/frontmatter-path-match.sh" "$PATHNAME" "${GLOBS[@]}"; then
        MATCHED=1
        break
      fi
    done

    if ! ((MATCHED)); then
      continue
    fi

    if ! (
      set -o noclobber
      : > "$SENTINELS/$STEM"
    ) 2> /dev/null; then
      continue
    fi

    CONTENT="$(awk "$AWK" < "$RULE")"
    CONTEXT+=("Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"$CONTENT")
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
printf -v CONTEXT_TEXT -- '<system-reminder>\n%s\n</system-reminder>' "${CONTEXT_TEXT%$'\n\n'}"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context,
  }
}
JQ
jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT_TEXT" "$JQ"
