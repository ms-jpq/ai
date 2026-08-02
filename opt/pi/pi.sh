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

PI="$ROOT/node_modules/.bin/pi"
EXEC=(
  "$ROOT/opt/libexec/harness.sh"
  "$PI" "$@"
)

export -- PI_CODING_AGENT_DIR="$ROOT/var/pi"
"${EXEC[@]}"
