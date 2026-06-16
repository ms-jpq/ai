#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ACTION="${1:-"open"}"
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
o | open)
  if [[ -n $NAME ]]; then
    NAME="$("$SELF/task-name.sh" "$NAME")"
  fi

  if [[ -z $NAME ]]; then
    "$SELF/pool.sh" init
    exec -- ~/.local/bin/tmux-open "$ROOT_NOTES"
  fi

  WORKTREE="$("$SELF/pool.sh" add "$NAME")"
  exec -- ~/.local/bin/tmux-open "$WORKTREE"
  ;;
e | edit)
  if (($# == 0)); then
    "$SELF/pool.sh" init
    # shellcheck disable=SC2154,SC2086
    exec -- env -C "$ROOT_NOTES" -- $EDITOR -- .
  fi

  for SRC in "$@"; do
    NAME="$("$SELF/task-name.sh" "$SRC")"
    BRIEF="$ROOT_NOTES/tasks/$NAME.md"
    WORKTREE="$("$SELF/pool.sh" add "$NAME")"
    DST="$WORKTREE/.notes/TASK.md"
    if [[ -f $BRIEF && ! -L $BRIEF ]]; then
      mv -- "$BRIEF" "$DST"
    fi

    touch -- "$DST"
    ln -v -sTnfr -- "$DST" "$BRIEF"
  done

  if (($# == 1)); then
    # shellcheck disable=SC2154,SC2086
    env -C "$ROOT_NOTES" -- $EDITOR -- "$BRIEF"
    "$SELF/commit-on-change.sh" "$BRIEF" edit
  fi
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
rm | remove)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" remove < <(printf -- '%s\0' "$@")
  fi

  tmux kill-session -t "=$SESSION" || true
  "$SELF/pool.sh" remove "$NAME"
  ;;
reap)
  if (($# > 1)); then
    exec -- "${FANOUT[@]}" reap < <(printf -- '%s\0' "$@")
  fi

  # TODO:
  printf -- '%s\n' "reap $NAME — not yet implemented" >&2
  exit 69
  ;;
*)
  PROG="${0##*/}"
  tee -- >&2 <<- EOF
	usage: $PROG [-h] {open,edit,resume,watch,remove,reap} ...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
