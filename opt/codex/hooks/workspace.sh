#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

SELF="$(realpath -- "$0")"
LIBEXEC="${SELF%/*}/../libexec/worktree"
WS=(env -C "$CWD" -- "$LIBEXEC/pool.sh")

case "$EVENT" in
SessionStart)
  exec -- "${WS[@]}" init > /dev/null
  ;;
*)
  ;;
esac
