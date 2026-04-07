#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

case "$OSTYPE" in
darwin*)
  CC='/opt/homebrew/bin/claude'
  ;;
linux*)
  CC='/usr/bin/claude-code'
  ;;
*)
  exit 2
  ;;
esac

export -- CLAUDE_CONFIG_DIR="$ROOT/var/claude"

COLOURS=(blue green yellow purple orange pink cyan)
RANDOM_COLOR="${COLOURS[RANDOM%${#COLOURS[@]}]}"

exec -- ~/.local/bin/hp "$CC" "$@" <<< "/color $RANDOM_COLOR"
