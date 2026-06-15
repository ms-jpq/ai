#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ACTION="${1:-"ls"}"
if (($#)); then
  shift -- 1
fi
FANOUT=(xargs -0 -r --max-args 1 -- "$0")

NAME="${1:-}"
COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"
SESSION="worktree/${ROOT##*/}/$NAME"
SESSION="${SESSION//[.:]/-}"
NOTES="$ROOT/.notes/worktrees/$NAME"
PROMPT="$NOTES/PROMPT.md"

case "$ACTION" in
l | ls)
  if ! [[ -t 1 ]]; then
    exec -- "$SELF/git.sh" list "$@"
  fi

  if ! [[ -t 0 ]]; then
    set -x
    exit 2
  fi

  FZF=(
    fzf
    --read0
    --delimiter /
    --preview "${SELF@Q}/preview.sh ${ROOT@Q} {-1}"
    --preview-window 'right,60%,wrap'
  )
  if ! SESSION="$("$0" ls "$@" | sort -z | "${FZF[@]}")" || [[ -z $SESSION ]]; then
    exit 0
  fi

  YAZI=("$HOME/.local/libexec/yazi.sh" -- "$ROOT/.notes/worktrees/${SESSION##*/}")

  if ! tmux has-session -t "=$SESSION" 2> /dev/null; then
    exec -- tmux new-window -a -- "${YAZI[@]}"
  fi

  tmux new-window -t "=$SESSION:" -- "${YAZI[@]}"
  exec -- tmux switch-client -t "=$SESSION"
  ;;
k | kill)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" kill < <(printf -- '%s\0' "$@")
  fi

  read -r -p "kill $SESSION? [y/N] " -- REPLY
  if [[ $REPLY == [Yy]* ]]; then
    tmux kill-session -t "=$SESSION"
  fi
  ;;
rm | remove)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" remove < <(printf -- '%s\0' "$@")
  fi

  "$0" kill "$NAME" || true
  "$SELF/git.sh" remove "$NAME"
  ;;
p | provision)
  "$SELF/git.sh" init
  for SRC in "$@"; do
    NAME="${SRC##*/}"
    NAME="${NAME%.md}"
    WORKTREE="$("$SELF/git.sh" add "$NAME")"
    ln -v -sTnfr -- "$SRC" "$WORKTREE/.notes/PROMPT.md"
  done
  ;;
r | run)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" run < <(printf -- '%s\0' "$@")
  fi

  if ! [[ -f $PROMPT ]]; then
    set -x
    exit 3
  fi
  WORKTREE="$("$SELF/git.sh" add "$NAME")"
  P="$(realpath --relative-to "$WORKTREE" -- "$PROMPT")"

  TMP="$(mktemp).sh"
  {
    ENV=TMUX_NO_SAVE

    printf -- '%q ' tmux set-environment -g -h -- "$ENV" 1
    printf -- '\n'

    printf -- '%q ' tmux new-window -c "$WORKTREE"
    printf -- '\n'
    printf -- '%q ' tmux set-buffer -- "claude --continue -- continue || claude --agent wtree-worker --name ${SESSION@Q} -- ${P@Q}"
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

  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  ;;
resume)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" resume < <(printf -- '%s\0' "$@")
  fi

  # TODO:
  printf -- '%s\n' "resume $NAME — not yet implemented" >&2
  exit 69
  ;;
run-all)
  "$0" ls | "${FANOUT[@]}" run
  tmux choose-tree -G -Z -s -NN
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {ls,kill,remove,provision,run,resume,run-all} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
