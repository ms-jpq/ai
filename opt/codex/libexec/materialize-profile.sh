#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
SRC="$1"
DST="$2"
DST_DIR="${DST%/*}"
DST_DIR="$(realpath -- "$DST_DIR")"
ROOT="$(realpath -- "$BASE/../../..")"

export -- CODEX_HOME="$ROOT/var/codex"
set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

mkdir -p -- "$DST_DIR"
if [[ -L $DST ]]; then
  rm -f -- "$DST"
fi
touch -- "$DST"

envsubst < "$SRC" | "$BASE/materialize-profile.awk" - "$DST" | sponge -- "$DST"
