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
  printf -v QUOTED -- '%q' "$SESSION"

  TMP="$(mktemp).sh"
  {
    ENV=TMUX_NO_SAVE

    printf -- '%q ' tmux set-environment -g -h -- "$ENV" 1
    printf -- '\n'

    printf -- '%q ' tmux new-window -c "$WORKTREE"
    printf -- '\n'
    printf -- '%q ' tmux set-buffer -- "claude --continue || claude --name $QUOTED "$'\n'
    printf -- '\n'
    printf -- '%q ' tmux paste-buffer -d -p
    printf -- '\n'
    printf -- '%q ' tmux select-pane -t '{marked}'
    printf -- '\n'
    printf -- '%q ' tmux select-pane -M
    printf -- '\n'

    # tmux select-window -t :-1
    printf -- '%q ' tmux set-environment -g -h -u -- "$ENV"
  } > "$TMP"
  chmod +x -- "$TMP"

  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  rm -fr -- "$TMP"
  ;;
all)
  "$SELF/tree.sh" list | xargs -0 -r -I % -- "$0" attach %
  ;;
*)
  set -v
  exit 2
  ;;
esac
