#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'perplexica'
  --no-buffer
  --json @-
  -- 'https://api.openai.com/v1/chat/completions'
)
JQ=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.choices[].delta.content // ""'
)

hr() {
  printf -- '\n'
  hr.sh "$@"
  printf -- '\n'
}

{

  hr '>'
  "${CURL[@]}" | sed -E -n -u -e 's/^data:[[:space:]]+(\{.*)/\1/gp' | "${JQ[@]}" | md-pager.sh "$@"
  printf -- '\n'
  hr '<'
} >&2
