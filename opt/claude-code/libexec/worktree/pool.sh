#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ACTION="${1:-"list"}"
if [[ ${1:-} == set-status ]] && ! [[ -v LOCKED ]]; then
  LOCKED=1 exec -- ~/.local/libexec/flock.sh "$0" "$0" "$@"
fi
if (($#)); then
  shift -- 1
fi

if ! GITDIR="$(git rev-parse --path-format=absolute --git-common-dir)" 2> /dev/null; then
  exit
fi

ROOT="${GITDIR%/.git}"
EXP="$ROOT/.exp"
NOTES="$ROOT/.notes"
NOTESTREE="$NOTES/worktrees"
WORKTREES="$ROOT/.worktrees"

case "$ACTION" in
session)
  SESSION="worktree/${ROOT##*/}/$1"
  printf -- '%s' "${SESSION//[.:]/-}"
  ;;
init)
  for DIR in "$EXP" "$NOTES"; do
    "$SELF/orphan.sh" "$DIR" "\$${DIR##*/.}"
  done

  rsync --archive --keep-dirlinks -- "$SELF/template/root/" "$ROOT/"

  for DIR in "$EXP" "$NOTES"; do
    if ! git -C "$DIR" rev-parse --verify --quiet HEAD > /dev/null; then
      git -C "$DIR" add -A
      git -C "$DIR" commit -q -m init
    fi
  done
  ;;
add)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"
  SELFNOTES="$WORKTREE/.notes"

  "$0" init

  "$SELF/orphan.sh" "$NOTESTREE/$NAME" "notes/$NAME"

  if ! [[ -e "$WORKTREE/.git" ]]; then
    git -C "$ROOT" worktree add --quiet -- "$WORKTREE"
  fi

  ln -sTnfr -- "$NOTESTREE/$NAME" "$SELFNOTES"
  rsync --archive --keep-dirlinks -- "$SELF/template/worktree/" "$WORKTREE/"

  "$0" set-status "$NAME" running

  if ! git -C "$NOTESTREE/$NAME" rev-parse --verify --quiet HEAD > /dev/null; then
    git -C "$NOTESTREE/$NAME" add -A
    git -C "$NOTESTREE/$NAME" commit -q -m running
  fi

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

  git -C "$NOTESTREE/$NAME" add -A
  git -C "$NOTESTREE/$NAME" commit -q --allow-empty -m reaped
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
  touch -- "$DIR/.STATUS-${STATE^^}"
  find "$DIR" -mindepth 1 -maxdepth 1 -type f -name '.STATUS-*' ! -name ".STATUS-${STATE^^}" -delete
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
      ARGS+=(-o -name ".STATUS-${STATE^^}")
      ;;
    all)
      ARGS+=(-o -name '.STATUS-*')
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
  SED=(sed -E -e 's#/\.STATUS-[^/]*$##' -e 's#^.*/##')
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
