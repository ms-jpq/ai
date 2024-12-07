#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}/../.."
COOKIE_JAR="$BASE/var/perplexica.cookies"

CURL=(
  curl
  --cookie "$COOKIE_JAR"
  --cookie-jar "$COOKIE_JAR"
  "$@"
)

exec -- "${CURL[@]}"
