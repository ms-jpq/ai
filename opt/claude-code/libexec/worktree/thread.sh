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
NOTES="$ROOT/.notes/worktree/$NAME"
PROMPT="$NOTES/PROMPT.md"

case "$ACTION" in
l | ls)
  if ! [[ -t 1 ]]; then
    exec -- "$SELF/pool.sh" list "$@"
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
    --preview-window 'right,80%,wrap'
  )
  if ! SESSION="$("$0" ls "$@" | sort -z | "${FZF[@]}")" || [[ -z $SESSION ]]; then
    exit 0
  fi

  YAZI=("$HOME/.local/libexec/yazi.sh" -- "$ROOT/.notes/worktree/${SESSION##*/}")

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
  "$SELF/pool.sh" remove "$NAME"
  ;;
n | new)
  "$SELF/pool.sh" init
  for SRC in "$@"; do
    BASE="${SRC%.md}"
    "$SELF/prompt.sh" seal "$SRC"

    NAME="${BASE##*/}"
    WORKTREE="$("$SELF/pool.sh" add "$NAME")"
    for EXT in md sum; do
      ln -v -sTnfr -- "$BASE.$EXT" "$WORKTREE/.notes/PROMPT.$EXT"
    done
  done
  ;;
r | resume)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" resume < <(printf -- '%s\0' "$@")
  fi

  if ! [[ -f $PROMPT ]]; then
    printf -- '%q\n' "$PROMPT"
    set -x
    exit 2
  fi
  WORKTREE="$("$SELF/pool.sh" add "$NAME")"
  P="$(realpath --relative-to "$WORKTREE" -- "$PROMPT")"
  RESUME=''
  if [[ -e "$NOTES/HISTORY.md" ]]; then
    RESUME='claude --continue -- continue || '
  fi

  TMP="$(mktemp).sh"
  {
    ENV=TMUX_NO_SAVE

    printf -- '%q ' tmux set-environment -g -h -- "$ENV" 1
    printf -- '\n'

    printf -- '%q ' tmux new-window -c "$WORKTREE"
    printf -- '\n'
    printf -- '%q ' tmux set-buffer -- "${RESUME}claude --agent wthread-worker --name ${SESSION@Q} -- ${P@Q}"
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
  "$XDG_CONFIG_HOME/tmux/libexec/switch-to.sh" "$SESSION" "$TMP" < /dev/null
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {ls,kill,remove,new,resume} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
