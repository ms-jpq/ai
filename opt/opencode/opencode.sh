#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

export -- LC_ALL='en_CA.UTF-8' OPENCODE_CONFIG="$BASE/opencode.json"
exec -- "$BASE/../libexec/harness.sh" "$ROOT/node_modules/.bin/opencode" "$@"
