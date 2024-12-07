#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
COOKIE_JAR="$BASE/../../var/$1.cookies"
shift -- 1

CURL=(
  curl
  --config "$BASE/.curlrc"
  --cookie "$COOKIE_JAR"
  --cookie-jar "$COOKIE_JAR"
  "$@"
)

exec -- "${CURL[@]}"
