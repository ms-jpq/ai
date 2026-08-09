#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${EDITOR?}"

FILE="$*"

"$EDITOR" "$FILE"
exec -- awk -- '{printf("%s%s", $0, "\\ ")}' "$FILE"
