#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

case "$EVENT" in
Stop | StopFailure)
  ;;
*)
  set -x
  exit 2
  ;;
esac

if jq -e '.agent_id' <<< "$JSON" > /dev/null; then
  exit
fi

NOTES="$CWD/.notes"
if ! [[ -d $NOTES ]] || ! [[ -e "$NOTES/.git" ]]; then
  exit
fi

LIBEXEC="${0%/*}/../libexec/worktree"

jq --raw-output '.last_assistant_message // ""' <<< "$JSON" > "$NOTES/.LAST_MESSAGE.md"

SUBJECT="$(head -n 1 -- "$NOTES/.LAST_MESSAGE.md")"
"$LIBEXEC/commit-on-change.sh" "$NOTES" "stop${SUBJECT:+ ~> $SUBJECT}"
