#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FILE="$*"

# shellcheck disable=2154
$EDITOR "$FILE"
exec -- awk -- '{printf("%s%s", $0, "\\ ")}' "$FILE"
