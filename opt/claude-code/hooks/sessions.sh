#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION="$(jq -e --raw-output '.session_id' <<< "$JSON")"

case "$EVENT" in
SessionStart)
  if [[ -n $CLAUDE_ENV_FILE ]]; then
    {
      printf -- '%q ' 'export' '--' "__CLAUDE_SESSION_ID=$SESSION"
      printf -- '\n'
    } >> "$CLAUDE_ENV_FILE"
  fi
  exit
  ;;
SessionEnd)
  exit
  ;;
UserPromptSubmit)
  ROLE='user'
  ;;
Stop)
  ROLE='assistant'
  ;;
*)
  set -x
  exit 2
  ;;
esac

SESSIONS="$(realpath -- "${0%/*}/../../../var/sessions")"
MD="$SESSIONS/$SESSION.md"
# shellcheck disable=2016
JQ=(
  jq -e --raw-output
  --arg role "$ROLE"
  '["# >>> \($role) <<<", "", .prompt // .last_assistant_message, "", "---", ""][]'
)

find "$SESSIONS" -name '*.md' -mtime +30 -delete 2> /dev/null || :
touch -- "$MD"

# shellcheck disable=SC2094
exec -- flock "$MD" "${JQ[@]}" <<< "$JSON" >> "$MD"
