#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION="$(jq -e --raw-output '.session_id' <<< "$JSON")"

DIR="${0%/*}"
SESSIONS="$(realpath -- "$DIR/../../../var/sessions")"

find "$SESSIONS" -mindepth 1 -mtime +30 -delete
if [[ -v TMUX_PANE ]]; then
  INDEX="$SESSIONS/$(tmux display-message -p '#{session_name}:#{window_index}:#{pane_index}').pos"
  printf -- '%s' "$SESSION" > "$INDEX"
fi

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

MD="$SESSIONS/$SESSION.md"
# shellcheck disable=2016
JQ=(
  jq -e --raw-output
  --arg role "$ROLE"
  '["# >>> \($role) <<<", "", .prompt // .last_assistant_message, "", "---", ""][]'
)

touch -- "$MD"

# shellcheck disable=SC2094
exec -- flock "$MD" "${JQ[@]}" <<< "$JSON" >> "$MD"
