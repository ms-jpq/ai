#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

if [[ $PWD == "$HOME" ]]; then
  TMP="$(mktemp -d)"
  cd -- "$TMP"
  exec -- "$0" "$@"
fi

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
PATH="$BASE/bin:$PATH"
ROOT="$(realpath -- "$BASE/../..")"

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

VAR="$ROOT/var"
export -- CLAUDE_CONFIG_DIR="$VAR/claude"
SANDBOX=()
case "$OSTYPE" in
darwin*)
  CC='/opt/homebrew/bin/claude'
  SANDBOX+=(
    ~/.local/opt/sandbox/libexec/sb-exec.sh
    --auth
    --network
    --dir "$VAR"
    --dir "$ROOT/opt/claude-code"
    --
  )
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
  nice
  -n 19
  -- "${SANDBOX[@]}"
  ~/.local/bin/hp
  "$CC" "${ARGV[@]}"
)

if [[ -t 0 ]]; then
  clear -x
  printf -- '%s' "/color $RANDOM_COLOR" | "${EXEC[@]}"
else
  "${EXEC[@]}"
fi
