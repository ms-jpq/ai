#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ACTION="${1:-"list"}"
if (($#)); then
  shift -- 1
fi

NAME="${1:-}"
COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"
SESSION="worktree/${ROOT##*/}/$NAME"
SESSION="${SESSION//[.:]/-}"

case "$ACTION" in
l | list)
  tmux list-sessions -f '#{m:worktree/*,#{session_name}}' -F '#{session_name}'
  ;;
k | kill)
  tmux kill-session -t "=$SESSION"
  ;;
a | attach)
  "$SELF/tree.sh" init
  WORKTREE="$("$SELF/tree.sh" add "$NAME")"
  INSTRUCTIONS="$ROOT/.notes/worktree/$NAME/PROMPT.md"

  printf -v QUOTED -- '%q' "$SESSION"
  # shellcheck disable=2016
  printf -v PROMPT -- '"$(< %q)"' "$INSTRUCTIONS"

  TMP="$(mktemp).sh"
  {
    ENV=TMUX_NO_SAVE

    printf -- '%q ' tmux set-environment -g -h -- "$ENV" 1
    printf -- '\n'

    printf -- '%q ' tmux new-window -c "$WORKTREE"
    printf -- '\n'
    printf -- '%q ' tmux set-buffer -- "claude --continue -- continue || claude --name $QUOTED -- $PROMPT"$'\n'
    printf -- '\n'
    printf -- '%q ' tmux paste-buffer -d -p
    printf -- '\n'
    printf -- '%q ' tmux select-pane -t '{marked}'
    printf -- '\n'
    printf -- '%q ' tmux select-pane -M
    printf -- '\n'

    # tmux select-window -t :-1
    printf -- '%q ' tmux set-environment -g -h -u -- "$ENV"
    printf -- '\n'

    printf -- '%q ' rm -fr -- "$TMP"
  } > "$TMP"
  chmod +x -- "$TMP"

  touch -- "$INSTRUCTIONS"
  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  ;;
all)
  "$SELF/tree.sh" list | xargs -0 -r -I % -- "$0" attach %
  tmux choose-tree -G -Z -s -NN
  ;;
*)
  set -v
  exit 2
  ;;
esac
