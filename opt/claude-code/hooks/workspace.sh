#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

if ! GITDIR="$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir)" 2> /dev/null; then
  exit
fi

ROOT="${GITDIR%/.git}"
EXP="$ROOT/.exp"
NOTES="$ROOT/.notes"
NOTESTREE="$NOTES/worktree"
WORKTREES="$ROOT/.worktrees"

case "$EVENT" in
SessionStart)
  ORPHANS=("$EXP" "$NOTES")
  for DIR in "${ORPHANS[@]}"; do
    BRANCH="${DIR##*/.}"
    if ! [[ -e "$DIR/.git" ]]; then
      git -C "$ROOT" worktree add --quiet --orphan -b "$BRANCH" -- "$DIR"
    fi
  done

  exit 0
  ;;
*)
  ;;
esac

case "$EVENT" in
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  NOTES="$NOTESTREE/$NAME"
  WORKTREE="$WORKTREES/$NAME"

  mkdir -p -- "$NOTES"
  printf -- '%s' "$WORKTREE"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  NAME="${WORKTREE##*/}"
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
