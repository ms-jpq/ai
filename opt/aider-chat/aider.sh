#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
ROOT="${BASE%/*}/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

exec -- "$ROOT/.venv/bin/aider" "$@"