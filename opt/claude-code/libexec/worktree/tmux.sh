#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

# shellcheck disable=SC2154
PREVIEW="$XDG_CONFIG_HOME/zsh/libexec/preview.sh"

ACTION="${1:-"list"}"
if (($#)); then
  shift -- 1
fi

NAME="${1:-}"
COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"
SESSION="worktree/${ROOT##*/}/$NAME"
SESSION="${SESSION//[.:]/-}"
NOTES="$ROOT/.notes/worktree/$NAME"
PROMPT="$NOTES/PROMPT.md"

case "$ACTION" in
l | list)
  tmux list-sessions -f '#{m:worktree/*,#{session_name}}' -F '#{session_name}' | grep -e .
  ;;
n | nav)
  if ! [[ -t 0 ]]; then
    set -v
    exit 2
  fi

  FZF=(
    fzf --delimiter /
    --preview "${PREVIEW@Q} ${ROOT@Q}/.notes/worktree/{-1}"
    --preview-window 'right,60%,wrap'
  )
  if ! SESSION="$("$0" list | "${FZF[@]}")" || [[ -z $SESSION ]]; then
    exit 0
  fi

  if [[ -v TMUX ]]; then
    exec -- tmux switch-client -t "=$SESSION"
  fi
  exec -- tmux attach-session -t "=$SESSION"
  ;;
k | kill)
  tmux kill-session -t "=$SESSION"
  ;;
p | prompt)
  "$SELF/git.sh" init
  mkdir -p -- "$NOTES"
  cat > "$PROMPT"
  printf -- '%s' ">>> $PROMPT" >&2
  ;;
r | run)
  "$SELF/git.sh" init
  WORKTREE="$("$SELF/git.sh" add "$NAME")"

  TMP="$(mktemp).sh"
  {
    ENV=TMUX_NO_SAVE

    printf -- '%q ' tmux set-environment -g -h -- "$ENV" 1
    printf -- '\n'

    printf -- '%q ' tmux new-window -c "$WORKTREE"
    printf -- '\n'
    printf -- '%q ' tmux set-buffer -- "claude --continue -- continue || claude --name ${SESSION@Q} -- \"\$(< ${PROMPT@Q})\""
    printf -- '\n'
    printf -- '%q ' tmux paste-buffer -d -p
    printf -- '\n'
    printf -- '%q ' tmux send-keys -- Enter
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

  touch -- "$PROMPT"
  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  ;;
all)
  "$SELF/git.sh" list | xargs -0 -r -I % -- "$0" run %
  tmux choose-tree -G -Z -s -NN
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {list,nav,kill,prompt,run,all} ...
	$PROG: error: argument command: invalid choice: '$ACTION' (choose from 'list', 'nav', 'kill', 'prompt', 'run', 'all')
EOF
  exit 2
  ;;
esac
