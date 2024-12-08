#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

ARGV=(
  "$ROOT/.venv/bin/aider"
  --light-mode
  --no-attribute-author
  --no-attribute-committer
  --no-gitignore
  --no-suggest-shell-commands
  "$@"
)
exec -- "${ARGV[@]}"
