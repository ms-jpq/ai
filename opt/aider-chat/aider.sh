#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
LC_ALL='en_CA.UTF-8'
set +a

ARG0="$ROOT/.venv/bin/aider"

ARGV=(
  "$ARG0"
  --light-mode
  --no-attribute-author
  --no-attribute-committer
  --no-gitignore
  --no-suggest-shell-commands
  "$@"
)

if ! [[ -f $ARG0 ]]; then
  make --directory "$ROOT" -- .venv/bin
fi

exec -- "${ARGV[@]}"
