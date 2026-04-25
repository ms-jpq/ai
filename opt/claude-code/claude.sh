#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
PATH="$BASE/bin:$PATH"
ROOT="$(realpath -- "$BASE/../..")"

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

ARGV=("$@")

COLOURS=(blue green yellow purple orange pink cyan)
RANDOM_COLOR="${COLOURS[RANDOM % ${#COLOURS[@]}]}"

for PLUGIN in "$BASE/local-plugins"/*/; do
  ARGV+=(--plugin-dir "$PLUGIN")
done

EXEC=(
  "$BASE/../libexec/harness.sh"
  "$CC" "${ARGV[@]}"
)

# shellcheck disable=SC1003
printf -- '\033]0;%s\033\\' "((${PWD##*/}))" >&2

export -- CLAUDE_CONFIG_DIR="$ROOT/var/claude"
if [[ -t 0 ]]; then
  clear -x
  printf -- '%s' "/color $RANDOM_COLOR" | "${EXEC[@]}"
else
  "${EXEC[@]}"
fi
