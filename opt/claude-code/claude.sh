#!/usr/bin/env -S -- bash

set -Eeu -o pipefail
shopt -s dotglob nullglob extglob globstar

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
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

PLUGINS=(
  "$BASE/local-plugins"/*/
  "$ROOT/var/claude-plugins"/*/
)

ARGV=("$@")
for PLUGIN in "${PLUGINS[@]}"; do
  ARGV+=(--plugin-dir "$PLUGIN")
done

EXEC=(
  "$ROOT/opt/libexec/harness.sh"
  "$CC" "${ARGV[@]}"
)

export -- CLAUDE_CONFIG_DIR="$ROOT/var/claude"
if [[ -t 0 ]]; then
  clear -x
fi

"${EXEC[@]}"
