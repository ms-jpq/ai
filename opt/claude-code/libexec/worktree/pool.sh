#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ACTION="${1:-"list"}"
if (($#)); then
  shift -- 1
fi

if ! GITDIR="$(git rev-parse --path-format=absolute --git-common-dir)" 2> /dev/null; then
  exit
fi

ROOT="${GITDIR%/.git}"
EXP="$ROOT/.exp"
NOTES="$ROOT/.notes"
NOTESTREE="$NOTES/worktree"
WORKTREES="$ROOT/.worktrees"

case "$ACTION" in
init)
  ORPHANS=("$EXP" "$NOTES")

  for DIR in "${ORPHANS[@]}"; do
    BRANCH="\$${DIR##*/.}"
    PRESS_F=(git -C "$ROOT" worktree add --quiet --orphan -b "$BRANCH" -- "$DIR")

    if [[ -e "$DIR/.git" ]]; then
      continue
    fi
    if [[ -d $DIR ]] && find "$DIR" -mindepth 1 -print -quit | grep --quiet -e .; then
      STASH="$(mktemp --dry-run --tmpdir="$ROOT")"
      mv -- "$DIR" "$STASH"
      "${PRESS_F[@]}"

      mv -- "$STASH"/* "$DIR/"
      rmdir -- "$STASH"
      continue
    fi

    "${PRESS_F[@]}"
  done
  ;;
add)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"
  SELFNOTES="$WORKTREE/.notes"

  if ! [[ -e "$WORKTREE/.git" ]]; then
    git -C "$ROOT" worktree add --quiet -- "$WORKTREE"
  fi
  mkdir -p -- "$NOTESTREE/$NAME"
  ln -sTnfr -- "$EXP" "$WORKTREE/.exp"
  ln -sTnfr -- "$NOTESTREE/$NAME" "$SELFNOTES"
  ln -sTnfr -- "$ROOT" "$SELFNOTES/->root"
  ln -sTnfr -- "$NOTESTREE" "$SELFNOTES/->peers"
  "$0" set-status "$NAME" running

  printf -- '%s' "$WORKTREE"
  ;;
remove)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"

  if [[ -e "$WORKTREE/.git" ]]; then
    git -C "$ROOT" worktree remove -- "$WORKTREE"
  fi
  if git -C "$ROOT" show-ref --verify --quiet -- "refs/heads/$NAME"; then
    git -C "$ROOT" branch --delete -- "$NAME" || true
  fi
  "$0" set-status "$NAME" reaped
  ;;
set-status)
  NAME="$1"
  STATE="$2"
  case "$STATE" in
  running | parked | reaped) ;;
  *)
    set -x
    exit 2
    ;;
  esac

  DIR="$NOTESTREE/$NAME"
  mkdir -p -- "$DIR"
  touch -- "$DIR/STATUS-${STATE^^}"
  find "$DIR" -mindepth 1 -maxdepth 1 -type f -name 'STATUS-*' ! -name "STATUS-${STATE^^}" -delete
  ;;
list)
  if ! [[ -d $NOTESTREE ]]; then
    exit
  fi

  STATES=("$@")
  if ((${#STATES[@]} == 0)); then
    STATES=(all)
  fi

  ARGS=()
  for STATE in "${STATES[@]}"; do
    case "$STATE" in
    running | parked | reaped)
      ARGS+=(-o -name "STATUS-${STATE^^}")
      ;;
    all)
      ARGS+=(-o -name 'STATUS-*')
      ;;
    *)
      PROG="${0##*/}"
      tee -- >&2 <<- EOF
	usage: $PROG list [-h] {running,parked,reaped,all}...
	$PROG list: error: argument status: invalid choice: '$STATE'
EOF
      exit 2
      ;;
    esac
  done
  ARGS=("${ARGS[@]:1}")

  FIND=(find "$NOTESTREE" -mindepth 2 -maxdepth 2 -type f '(' "${ARGS[@]}" ')')
  SED=(sed -E -e 's#/STATUS-[^/]*$##' -e 's#^.*/##')
  if [[ -t 1 ]]; then
    FIND+=(-print)
  else
    FIND+=(-print0)
    SED+=(-z)
  fi
  "${FIND[@]}" | "${SED[@]}"
  ;;
*)
  set -x
  exit 2
  ;;
esac
