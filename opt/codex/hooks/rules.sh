#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="$(realpath -- "${0%/*}/..")"
PARSE_PATHS="$BASE/libexec/frontmatter-path.sed"

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

  PATH_CONTEXT=()
  for RULE in "$RULES"/*.md; do
    if PATHS="$("$PARSE_PATHS" "$RULE" | grep -e .)"; then
      PATH_CONTEXT+=("Rule $RULE applies to paths:"$'\n'"$(tr -- '\n' ' ' <<< "$PATHS")")
      continue
    fi

    CONTENT="$(awk "$AWK" < "$RULE")"
    CONTEXT+=("Contents of $RULE (project instructions, checked into the codebase):"$'\n\n'"$CONTENT")
  done

  if ((${#PATH_CONTEXT[@]})); then
    CONTEXT+=('---')
  fi
  CONTEXT+=("${PATH_CONTEXT[@]}")
  ;;
PostToolUse)
  TMP="$(mktemp)"
  trap 'rm -fr -- "$TMP"' EXIT

  if ! "$BASE/libexec/parse-hook-paths.sh" <<< "$JSON" > "$TMP"; then
    exit
  fi
  readarray -d '' -t -- PATHNAMES < "$TMP"

  mkdir -p -- "$SENTINELS"

  CONTEXT=()
  for RULE in "$RULES"/*.md; do
    STEM="${RULE##*/}"
    STEM="${STEM%.md}"

    if [[ -e $SENTINELS/$STEM ]] || ! GB="$("$PARSE_PATHS" "$RULE" | grep -e .)"; then
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
