#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

if ! GITDIR="$(git -C "$CWD" rev-parse --git-common-dir --path-format=absolute)" 2> /dev/null; then
  exit
fi
ROOT="${GITDIR%/.git}"
WORKTREES="$ROOT/.worktrees"

case "$EVENT" in
SessionStart)
  NOTES="$ROOT/.notes"
  DIRS=(
    "$ROOT/.exp"
    "$NOTES"
    "$WORKTREES"
  )
  SUBDIRS=(
    "$NOTES/design"
    "$NOTES/plan"
    "$NOTES/research"
    "$NOTES/worktree"
  )

  mkdir -p -- "${DIRS[@]}" "${SUBDIRS[@]}"
  for DIR in "${DIRS[@]}"; do
    if ! [[ -d "$DIR/.git" ]]; then
      git -C "$DIR" init --quiet
    fi
  done
  for DIR in "${SUBDIRS[@]}"; do
    touch -- "$DIR/.gitignore"
  done

  exit 0
  ;;
*)
  NOTES="$ROOT/.notes/worktree"
  ;;
esac

case "$EVENT" in
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  WORKTREE="$WORKTREES/$NAME"

  printf -- '%s' "$WORKTREE"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  NAME="${WORKTREE##*/}"

  ;;
*)
  set -v
  exit 2
  ;;
esac
