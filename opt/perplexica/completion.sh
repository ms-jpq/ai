#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'perplexica'
  --no-buffer
  --json @-
  -- "$PERPLEXICA_URL/api/search"
)
read -r -d '' -- JQ <<- 'JQ' || true

JQ
PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  "$JQ"
)

hr() {
  printf -- '\n'
  hr.sh "$@"
  printf -- '\n'
}

{

  hr '>'
  "${CURL[@]}" | "${PARSE[@]}" | md-pager.sh "$@"
  printf -- '\n'
  hr '<'
} >&2
