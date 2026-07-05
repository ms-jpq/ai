#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
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
read -r -d '' -- JQ <<- 'JQ' || true
del(."$schema") | paths(scalars) as $p | "\($p | join("."))=\(getpath($p))"
JQ

LS="$(jq -e --raw-output "$JQ" "$OVERRIDE")"
readarray -t LINES --- <<< "$LS"

ARGV=(--strict-config)
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
