#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TEE="$*"
CURL=(
  curl.sh
  --data @-
  --no-buffer
  -- 'https://api.openai.com/v1/chat/completions'
)
JQ=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.choices[].delta.content // ""'
)

BAT=(
  bat
  --unbuffered
  --style plain
  --paging never
  --language markdown
  -- -
)

hr() {
  {
    printf -- '\n'
    hr.sh "$@"
    printf -- '\n'
  } >&2
}

hr '?'
"${CURL[@]}" | sed -E -n -u -e 's/data: (\{.*)/\1/gp' | "${JQ[@]}" | tee -- "$TEE" | "${BAT[@]}"
printf -- '\n' >&2
hr '<'
