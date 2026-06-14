#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

EVENT="$1"
CWD="$2"
shift -- 2

if ! GITDIR="$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir)" 2> /dev/null; then
  exit
fi

ROOT="${GITDIR%/.git}"
EXP="$ROOT/.exp"
NOTES="$ROOT/.notes"
NOTESTREE="$NOTES/worktree"
WORKTREES="$ROOT/.worktrees"

case "$EVENT" in
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
up)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"

  git -C "$ROOT" worktree add --quiet -- "$WORKTREE"
  mkdir -p -- "$NOTESTREE/$NAME"
  ln -sTnf -- "$EXP" "$WORKTREE/.exp"
  ln -sTnf -- "$NOTESTREE/$NAME" "$WORKTREE/.notes"
  printf -- '%s' "$WORKTREE"
  ;;
down)
  NAME="$1"
  WORKTREE="$WORKTREES/$NAME"
  NOTES="$NOTESTREE/$NAME"

  if git -C "$CWD" worktree remove -- "$WORKTREE"; then
    mkdir -p -- "$NOTES"
    chmod +t -- "$NOTES"
    touch -- "$NOTES/DEAD.md"
  fi
  ;;
*)
  set -v
  exit 2
  ;;
esac
