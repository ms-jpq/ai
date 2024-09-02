#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}/../.."
COOKIE_JAR="$BASE/var/claude.cookies"

CURL=(
  curl
  --header 'Content-Type: application/json'
  --cookie "$COOKIE_JAR"
  --cookie-jar "$COOKIE_JAR"
  --header 'Anthropic-Version: 2023-06-01'
  --header "X-API-Key: $ANTHROPIC_API_KEY"
  --no-progress-meter
  "$@"
)

exec -- "${CURL[@]}"
