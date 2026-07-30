#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
AWK=(awk -f "$BASE/slop-cop.awk")

for FRAGMENT in "$BASE/../slop.d"/*.awk; do
  AWK+=(-f "$FRAGMENT")
done

exec -- "${AWK[@]}" "$@"
