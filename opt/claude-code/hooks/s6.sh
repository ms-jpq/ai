#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
BASE="$(realpath -- "${0%/*}/..")"

if jq -e '.agent_id' <<< "$JSON" > /dev/null; then
  exit
fi

SCRATCHPAD="$(jq -e --raw-output '.scratchpad_dir' <<< "$JSON")"
INIT="$BASE/libexec/s6/init.sh"
STATE="$SCRATCHPAD/s6-init"

case "$EVENT" in
SessionStart)
  WORKSPACE="$(jq -e --raw-output '.cwd' <<< "$JSON")"
  S67_HARNESS_PID="${CLAUDE_PID?}"
  S67_HARNESS_STARTED="$(LC_ALL=C.UTF-8 ps -p "$S67_HARNESS_PID" -o lstart=)"
  export -- S67_HARNESS_PID S67_HARNESS_STARTED
  exec -- "$INIT" start "$STATE" "$WORKSPACE"
  ;;
SessionEnd)
  exec -- "$INIT" shutdown "$STATE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
