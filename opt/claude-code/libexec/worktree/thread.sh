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
SESSION="$("$SELF/pool.sh" session "$NAME")"
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
    --bind "enter:become(${SELF@Q}/tmux.sh nav {-1} ${ROOT@Q}/.notes/worktree/{-1})"
  )
  "$0" ls "$@" | sort -z | "${FZF[@]}"
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

  README=''
  if "$SELF/prompt.sh" drifted "$PROMPT"; then
    "$SELF/prompt.sh" seal "$PROMPT"
    if [[ -e "$NOTES/HISTORY.md" ]]; then
      README='Your brief changed since you last read it — re-read it.'
    fi
  fi
  read -r -d '' -- MESSAGE <<- JQ || true
$README

$(realpath --relative-to "$WORKTREE" -- "$PROMPT")
JQ
  RESUME="claude --agent wthread-worker --name ${SESSION@Q} -- ${MESSAGE@Q}"
  if [[ -e "$NOTES/HISTORY.md" ]]; then
    RESUME="claude --continue -- ${MESSAGE@Q} || $RESUME"
  fi

  exec -- "$SELF/tmux.sh" launch "$SESSION" "$WORKTREE" "$RESUME"
  ;;
k | kill)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" kill < <(printf -- '%s\0' "$@")
  fi

  read -r -p "kill $SESSION? [y/N] " -- REPLY < /dev/tty
  if [[ $REPLY == [Yy]* ]]; then
    tmux kill-session -t "=$SESSION"
  fi
  ;;
reap)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" reap < <(printf -- '%s\0' "$@")
  fi

  # TODO:
  printf -- '%s\n' "reap $NAME — not yet implemented" >&2
  exit 69
  ;;
rm | remove)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" remove < <(printf -- '%s\0' "$@")
  fi

  "$0" kill "$NAME" || true
  "$SELF/pool.sh" remove "$NAME"
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {ls,new,resume,kill,reap,remove} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
