#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

PROG="${0##*/}"

ACTION="${1:-}"
if (($#)); then
  shift -- 1
fi

COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"
ROOT_NOTES="$ROOT/.notes"
REPO="${ROOT##*/}"

case "$ACTION" in
rebase)
  TOP="$(git rev-parse --show-toplevel)"
  if [[ $TOP == "$ROOT" ]]; then
    WORKER="${1:-}"
    if [[ -z $WORKER ]]; then
      set -x
      exit 2
    fi

    TOP="$ROOT/.worktrees/$WORKER"
    if [[ ! -e "$TOP/.git" ]]; then
      set -x
      exit 2
    fi
  fi
  ONTO="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  exec -- git -C "$TOP" rebase -- "$ONTO"
  ;;
m | merge)
  TOP="$(git rev-parse --show-toplevel)"
  if [[ $TOP == "$ROOT" ]]; then
    tee -- >&2 <<- EOF
	$PROG: $ACTION must run from a worker worktree, not the root
EOF
    exit 2
  fi
  BRANCH="$(git -C "$TOP" rev-parse --abbrev-ref HEAD)"
  exec -- git -C "$ROOT" merge --no-ff --no-edit -- "$BRANCH"
  ;;
b | backup)
  # Namespace every $exp and $notes* branch under the root repo's name on a
  # target git repo: <repo>/$exp, <repo>/$notes, <repo>/$notes$<worker>.
  TARGET="${1:-}"
  if [[ -z $TARGET ]]; then
    tee -- >&2 <<- EOF
	$PROG: $ACTION needs a target git repo
EOF
    exit 2
  fi
  # git -C <worktree> runs with a different cwd, so a relative path would break.
  if [[ -e $TARGET ]]; then
    TARGET="$(realpath -- "$TARGET")"
  fi

  # shellcheck disable=SC2016 # literal $exp / $notes are branch names
  LOCAL="$(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/$exp' 'refs/heads/$notes*')"
  if [[ -z $LOCAL ]]; then
    printf -- '%s\n' "$PROG: nothing to back up" >&2
    exit 1
  fi
  readarray -t -- BRANCHES <<< "$LOCAL"

  PUSH=(git -C "$ROOT" push --force --atomic -- "$TARGET")
  for BRANCH in "${BRANCHES[@]}"; do
    PUSH+=("refs/heads/$BRANCH:refs/heads/$REPO/$BRANCH")
  done
  exec -- "${PUSH[@]}"
  ;;
restore)
  TARGET="${1:-}"
  if [[ -z $TARGET ]]; then
    tee -- >&2 <<- EOF
	$PROG: $ACTION needs a target git repo
EOF
    exit 2
  fi
  if [[ -e $TARGET ]]; then
    TARGET="$(realpath -- "$TARGET")"
  fi

  # --key=2 sorts by refname so $notes lands before $notes$<worker> — the
  # parent worktree dir must exist before its nested worktrees are added.
  REMOTE="$(git -C "$ROOT" ls-remote --heads -- "$TARGET" "refs/heads/$REPO/*" | sort --key=2)"
  if [[ -z $REMOTE ]]; then
    printf -- '%s\n' "$PROG: no backup for ${REPO@Q} at $TARGET" >&2
    exit 1
  fi
  readarray -t -- LINES <<< "$REMOTE"

  for LINE in "${LINES[@]}"; do
    # ls-remote line is "<sha>\trefs/heads/<repo>/<branch>"; branch has no /.
    BRANCH="${LINE##*/}"
    # shellcheck disable=SC2016 # literal $exp / $notes are branch names
    case "$BRANCH" in
    '$exp') DIR="$ROOT/.exp" ;;
    '$notes') DIR="$ROOT_NOTES" ;;
    '$notes$'*) DIR="$ROOT_NOTES/worktrees/${BRANCH#\$notes\$}" ;;
    *)
      set -x
      exit 2
      ;;
    esac

    REF="refs/heads/$REPO/$BRANCH"
    if [[ -e "$DIR/.git" ]]; then
      # Branch is checked out here; FETCH_HEAD + reset moves it and the tree.
      git -C "$DIR" fetch --no-tags --quiet -- "$TARGET" "$REF"
      git -C "$DIR" reset --hard --quiet FETCH_HEAD
    else
      git -C "$ROOT" fetch --no-tags --quiet -- "$TARGET" "+$REF:refs/heads/$BRANCH"
      mkdir -p -- "${DIR%/*}"
      git -C "$ROOT" worktree add --force --quiet -- "$DIR" "$BRANCH"
    fi
    printf -- '%s -> %s\n' "$BRANCH" "$DIR"
  done
  ;;
reap)
  # A reap is a backup followed by selective pruning: archive everything to the
  # target, then drop the named workers' now-backed-up notes ($notes$<worker>).
  TARGET="${1:-}"
  if [[ -z $TARGET ]]; then
    tee -- >&2 <<- EOF
	$PROG: $ACTION needs a target git repo
EOF
    exit 2
  fi
  shift -- 1

  # set -e (shebang) aborts here if the backup fails, so pruning only runs once
  # the notes are safely on the target.
  "$0" backup "$TARGET"

  for WORKER in "$@"; do
    DIR="$ROOT_NOTES/worktrees/$WORKER"
    if [[ -e "$DIR/.git" ]]; then
      git -C "$ROOT" worktree remove --force -- "$DIR"
    fi
    BRANCH="\$notes\$$WORKER"
    if git -C "$ROOT" show-ref --verify --quiet -- "refs/heads/$BRANCH"; then
      git -C "$ROOT" branch --delete --force -- "$BRANCH"
    fi
    printf -- '%s -> reaped\n' "$WORKER"
  done
  ;;
*)
  tee -- >&2 <<- EOF
	usage: $PROG rebase [worker] | $PROG merge | $PROG {backup,restore} <target> | $PROG reap <target> <worker>...
	$PROG: error: argument command: invalid choice: '$ACTION'
EOF
  exit 2
  ;;
esac
