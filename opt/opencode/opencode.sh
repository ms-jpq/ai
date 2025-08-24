#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

OPENCODE_CONFIG="$BASE/opencode.json"
export -- LC_ALL='en_CA.UTF-8' OPENCODE_CONFIG

exec -- "$ROOT/node_modules/.bin/opencode" "$@"
