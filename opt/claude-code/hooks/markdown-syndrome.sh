#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq --raw-output '.hook_event_name' <<< "$JSON")"
case "$EVENT" in
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

SESSION="$(jq --raw-output '.session_id' <<< "$JSON")"

STORE="$PWD/.markdown"
MD="$STORE/$SESSION.md"

mkdir -p -- "$STORE"
jq --raw-output --arg role "$ROLE" '["# >>> $role <<<", "", .prompt // .last_assistant_message, "", "---"][]' <<< "$JSON" >> "$MD"

printf -- '%s' '{}'
