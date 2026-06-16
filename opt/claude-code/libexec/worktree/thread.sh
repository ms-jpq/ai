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
ROOT_NOTES="$ROOT/.notes"
SESSION="$("$SELF/pool.sh" session "$NAME")"
NOTES="$ROOT_NOTES/worktrees/$NAME"
TASK="$NOTES/TASK.md"

case "$ACTION" in
l | ls)
  if [[ ${1:-} == running ]]; then
    exec -- tmux choose-tree -G -Z -s -O name -NN -f "#{m:${SESSION%/*}/*,#{session_name}}"
  fi

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
    --bind "enter:become(${SELF@Q}/tmux.sh nav {-1} ${ROOT_NOTES@Q}/worktrees/{-1})"
  )
  "$0" ls "$@" | sort -z | "${FZF[@]}"
  ;;
n | new)
  for SRC in "$@"; do
    NAME="$("$SELF/task-name.sh" name "$SRC")"
    BRIEF="$("$SELF/task-name.sh" path "$NAME")"
    WORKTREE="$("$SELF/pool.sh" add "$NAME")"
    DST="$WORKTREE/.notes/TASK.md"
    if [[ -f $BRIEF && ! -L $BRIEF ]]; then
      mv -- "$BRIEF" "$DST"
    fi

    touch -- "$DST"
    ln -v -sTnfr -- "$DST" "$BRIEF"
  done

  if (($# == 1)); then
    exec -- "$0" edit "$NAME"
  fi
  ;;
o | open)
  WORKTREE="$("$SELF/pool.sh" add "$NAME")"
  exec -- ~/.local/bin/tmux-open "$WORKTREE"
  ;;
e | edit)
  SRC="$("$SELF/task-name.sh" path "$NAME")"
  mkdir -p -- "${SRC%/*}"
  # shellcheck disable=SC2154,SC2086
  env -C "$ROOT_NOTES" -- $EDITOR -- "$SRC"
  "$SELF/commit-on-change.sh" "$SRC" edit
  ;;
r | resume)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" resume < <(printf -- '%s\0' "$@")
  fi

  if ! [[ -s $TASK ]]; then
    "$0" edit "$NAME"
  fi
  WORKTREE="$("$SELF/pool.sh" add "$NAME")"

  MESSAGE="$(realpath --relative-to "$WORKTREE" -- "$TASK")"
  RESUME="claude --agent wt-worker --name ${SESSION@Q} -- ${MESSAGE@Q}"
  if [[ -e "$NOTES/.HISTORY.md" ]]; then
    RESUME="claude --continue -- ${MESSAGE@Q} || $RESUME"
  fi

  exec -- "$SELF/tmux.sh" launch "$SESSION" "$WORKTREE" "$RESUME"
  ;;
w | watch)
  if (($#)); then
    MSG="$NOTES/LAST_MESSAGE.md"
    if [[ -f $MSG ]]; then
      HR=(~/.local/libexec/hr.sh '#')
      if [[ -v COLUMNS ]]; then
        HR+=($((COLUMNS - 8)))
      fi
      {
        "${HR[@]}"
        printf -- '%s\n' "# >>> $NAME <<<"
        tail -n 16 -- "$MSG"
      } | CLICOLOR_FORCE=1 glow --style light
    fi
    exit
  fi

  if ! command -v -- watch > /dev/null || [[ -v WATCHING ]]; then
    "$SELF/pool.sh" list parked | "${FANOUT[@]}" watch
  else
    WATCHING=1 exec -- watch --color -- "$0" watch
  fi
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
	usage: $PROG [-h] {ls,new,open,edit,resume,watch,kill,reap,remove} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
