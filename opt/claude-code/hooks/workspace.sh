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

  exit 0
  ;;
*)
  ;;
esac

case "$EVENT" in
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  WORKTREE="$WORKTREES/$NAME"

  git worktree add --quiet -- "$WORKTREE"
  mkdir -p -- "$NOTESTREE/$NAME"
  printf -- '%s' "$WORKTREE"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  NOTES="$NOTESTREE/${WORKTREE##*/}"

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
