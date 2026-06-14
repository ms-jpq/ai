#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

SELF="$(realpath -- "$0")"
WORKSPACE="${SELF%/*}/../worktree/libexec/workspace.sh"

case "$EVENT" in
SessionStart)
  exec -- "$WORKSPACE" init "$CWD"
  ;;
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  exec -- "$WORKSPACE" up "$CWD" "$NAME"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  exec -- "$WORKSPACE" down "$CWD" "${WORKTREE##*/}"
  ;;
*)
  set -v
  exit 2
  ;;
esac
