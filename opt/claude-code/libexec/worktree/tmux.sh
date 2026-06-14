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
    exec -- "$SELF/git.sh" list all
  fi

  if ! [[ -t 0 ]]; then
    set -v
    exit 2
  fi

  FZF=(
    fzf
    --read0
    --delimiter /
    --preview "${SELF@Q}/preview.sh ${ROOT@Q} {-1}"
    --preview-window 'right,60%,wrap'
  )
  if ! SESSION="$("$0" ls | sort -z | "${FZF[@]}")" || [[ -z $SESSION ]]; then
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
p | prompt)
  "$SELF/git.sh" init
  mkdir -p -- "$NOTES"
  cat > "$PROMPT"
  printf -- '%s' ">>> $PROMPT" >&2
  ;;
r | run)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" run < <(printf -- '%s\0' "$@")
  fi

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

  if ! [[ -t 0 ]] && ! [[ /dev/stdin -ef /dev/null ]]; then
    "$0" prompt "$NAME"
  else
    touch -- "$PROMPT"
  fi
  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP"
  ;;
run-all)
  "$0" ls | "${FANOUT[@]}" run
  tmux choose-tree -G -Z -s -NN
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {ls,kill,remove,prompt,run,run-all} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
