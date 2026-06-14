#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ACTION="${1:-"list"}"
if (($#)); then
  shift -- 1
fi

case "$ACTION" in
l | list)
  tmux list-sessions -f '#{m:worktree/*,#{session_name}}' -F '#{session_name}'
  ;;
a | attach)
  NAME="$1"
  SESSION="worktree/$NAME"
  "$SELF/tree.sh" init
  WORKTREE="$("$SELF/tree.sh" add "$NAME")"

  TMP="$(mktemp).sh"
  {
    printf -- '%q ' tmux new-window -c "$WORKTREE"
  } > "$TMP"
  chmod +x -- "$TMP"

  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  ;;
*)
  set -v
  exit 2
  ;;
esac
