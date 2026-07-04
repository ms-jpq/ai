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
  OPENCODE='/opt/homebrew/bin/opencode'
  ;;
linux*)
  OPENCODE='/usr/bin/opencode'
  ;;
*)
  exit 2
  ;;
esac

ARGV=("$@")

# PLUGINS=(
#   "$BASE/local-plugins"/*/
#   "$ROOT/var/claude-plugins"/*/
# )
# for PLUGIN in "${PLUGINS[@]}"; do
#   ARGV+=(--plugin-dir "$PLUGIN")
# done

EXEC=(
  "$BASE/../libexec/harness.sh"
  "$OPENCODE" "${ARGV[@]}"
)

export -- LC_ALL='en_CA.UTF-8' OPENCODE_CONFIG_DIR="$ROOT/var/opencode" OPENCODE_DISABLE_LSP_DOWNLOAD=1

"${EXEC[@]}"
