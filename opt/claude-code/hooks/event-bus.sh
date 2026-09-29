#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

EVENTS="$CWD/.notes/events"
SIGNAL="$CWD/.events-ready"

if jq -e '.agent_id' <<< "$JSON" > /dev/null; then
  exit
fi

mkdir -p -- "$EVENTS"

case "$EVENT" in
SessionStart)
  ;;
FileChanged)
  FILE="$(jq -e --raw-output '.file_path' <<< "$JSON")"
  if ! [[ $FILE -ef $SIGNAL ]]; then
    exit
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac

if grep --recursive --quiet -- . "$EVENTS"; then
  tee >&2 <<- 'EOF'
Pending messages. Use `/event-bus read` to inspect and handle them when ready.
EOF
  exit 2
fi
