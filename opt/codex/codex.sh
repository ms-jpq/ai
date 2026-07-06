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
  CODEX='/opt/homebrew/bin/codex'
  ;;
linux*)
  CODEX='/usr/bin/codex'
  ;;
*)
  exit 2
  ;;
esac

OVERRIDE="$BASE/codex.json"
MCP_SRC="$ROOT/opt/claude-code/local-plugins/omnibus/.mcp.json"

MCP_RAW="$(envsubst < "$MCP_SRC")"
LS="$("$BASE/libexec/codex.jq" --raw-output --argjson mcp "$MCP_RAW" "$OVERRIDE")"
readarray -t LINES --- <<< "$LS"

ARGV=()
if [[ $* != login ]]; then
  ARGV+=(--strict-config)
fi
for LINE in "${LINES[@]}"; do
  ARGV+=(--config "$LINE")
done

EXEC=(
  "$BASE/../libexec/harness.sh"
  "$CODEX" "${ARGV[@]}"
  "$@"
)

export -- CODEX_HOME="$ROOT/var/codex"

"${EXEC[@]}"
