#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}/../.."
MARKDOWN="$1"

exec -- find -H "$BASE/lint.d" -type f -perm -u+x -exec '{}' "$MARKDOWN" ';'
