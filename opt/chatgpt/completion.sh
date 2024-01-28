#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TEE="$*"
CURL=(
  curl.sh
  --data @-
  -- 'https://api.openai.com/v1/chat/completions'
)
JQ=(
  jq
  --exit-status
  --join-output
  '.choices[].delta.content // ""'
)

hr() {
  {
    printf -- '\n'
    hr.sh "$@"
    printf -- '\n'
  } >&2
}

hr '?'
"${CURL[@]}" | sed -E -n -e 's/data: (\{.*)/\1/gp' | "${JQ[@]}" | tee -- "$TEE" | glow
printf -- '\n' >&2
hr '<'
