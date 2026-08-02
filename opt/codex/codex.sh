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
  export -- SSL_CERT_FILE=/etc/ssl/cert.pem
  CODEX='/opt/homebrew/bin/codex'
  ;;
linux*)
  CODEX='/usr/bin/codex'
  ;;
*)
  exit 2
  ;;
esac

MCP="$(envsubst < "$ROOT/opt/claude-code/local-plugins/omnibus/.mcp.json")"
LS="$(jq -e 'del(."$schema")' "$BASE/codex.json" | "$BASE/libexec/codex.jq" --raw-output --argjson mcp "$MCP")"
readarray -t LINES --- <<< "$LS"

ARGV=()
case "${1:-}" in
"" | exec | review | resume | fork | app-server | mcp-server | exec-server)
  ARGV+=(--strict-config)
  ;;
*)
  ;;
esac
for LINE in "${LINES[@]}"; do
  ARGV+=(--config "$LINE")
done

EXEC=(
  "$ROOT/opt/libexec/harness.sh"
  "$CODEX" "${ARGV[@]}"
  "$@"
)

export -- CODEX_HOME="$ROOT/var/codex"
"${EXEC[@]}"
