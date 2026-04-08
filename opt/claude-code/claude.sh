#!/usr/bin/env -S -- bash

set -eEu
set -o pipefail

if [[ $PWD == "$HOME" ]]; then
  set -x
  exit 2
fi

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
PATH="$BASE/bin:$PATH"
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

clear -x
printf -- '%s' "/color $RANDOM_COLOR" | exec -- ~/.local/bin/hp "$CC" "$@"
