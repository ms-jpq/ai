#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

DIR="$1"
BRANCH="$2"

if [[ -e "$DIR/.git" ]]; then
  exit
fi

COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"

ORPHAN=(git -C "$ROOT" worktree add --quiet --orphan -b "$BRANCH" -- "$DIR")

if [[ -d $DIR ]] && find "$DIR" -mindepth 1 -print -quit | grep --quiet -e .; then
  STASH="$(mktemp --dry-run --tmpdir="$ROOT")"
  mv -- "$DIR" "$STASH"
  "${ORPHAN[@]}"
  mv -- "$STASH"/* "$DIR/"
  rmdir -- "$STASH"
else
  "${ORPHAN[@]}"
fi
