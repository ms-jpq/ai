#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

SELF="$(realpath -- "$0")"
WS=(env -C "$CWD" -- "${SELF%/*}/../worktree/git.sh")

case "$EVENT" in
SessionStart)
  exec -- "${WS[@]}" init
  ;;
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  exec -- "${WS[@]}" add "$NAME"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  exec -- "${WS[@]}" remove "${WORKTREE##*/}"
  ;;
*)
  set -v
  exit 2
  ;;
esac
