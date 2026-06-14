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
NOTESTREE="$NOTES/worktrees"
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

  printf -- '%s' "$WORKTREE"
  ;;
remove)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"
  NOTES="$NOTESTREE/$NAME"

  if [[ -e "$WORKTREE/.git" ]]; then
    git -C "$ROOT" worktree remove -- "$WORKTREE"
  fi
  if git -C "$ROOT" show-ref --verify --quiet -- "refs/heads/$NAME"; then
    git -C "$ROOT" branch --delete -- "$NAME" || true
  fi
  mkdir -p -- "$NOTES"
  chmod +t -- "$NOTES"
  touch -- "$NOTES/DEAD.md"
  ;;
list)
  FIND=(find "$WORKTREES" -mindepth 1 -maxdepth 1 -type d)
  SED=(sed -E -e 's#^.*/##')
  TOMB=(-execdir test -e '../.notes/worktrees/{}/DEAD.md' ';')
  case "${1:-"live"}" in
  live)
    FIND+=('!' "${TOMB[@]}")
    ;;
  dead)
    FIND+=("${TOMB[@]}")
    ;;
  all)
    ;;
  *)
    set -v
    exit 2
    ;;
  esac
  if [[ -t 1 ]]; then
    FIND+=(-print)
  else
    FIND+=(-print0)
    SED+=(-z)
  fi
  "${FIND[@]}" | "${SED[@]}"
  ;;
*)
  set -v
  exit 2
  ;;
esac
