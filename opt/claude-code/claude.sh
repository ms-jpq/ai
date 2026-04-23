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

VAR="$ROOT/var"
SANDBOX=(
  ~/.local/opt/sandbox/libexec/dispatch.sh
  --auth
  --network
  --dir "$ROOT"
  --dir "$VAR:rw"
  --dir "$ROOT/opt/claude-code"
)

if CWD="$(~/.local/libexec/dnif.sh "$PWD")" && [[ $CWD != "$PWD" ]]; then
  SANDBOX+=(--dir "$CWD")
fi

EXEC=(
  nice
  -n 19
  -- "${SANDBOX[@]}"
  -- ~/.local/bin/hp
  "$CC" "${ARGV[@]}"
)

export -- CLAUDE_CONFIG_DIR="$VAR/claude"
if [[ -t 0 ]]; then
  clear -x
  printf -- '%s' "/color $RANDOM_COLOR" | "${EXEC[@]}"
else
  "${EXEC[@]}"
fi
