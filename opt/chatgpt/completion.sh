#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STREAMING="$1"
TEE="$2"

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

if ((STREAMING)); then
  MDPAGER=(tee --)
else
  MDPAGER=(
    bat
    --style plain
    --paging never
    --language markdown
    -- -
  )
fi

hr() {
  {
    printf -- '\n'
    hr.sh "$@"
    printf -- '\n'
  } >&2
}

hr '?'
"${CURL[@]}" | sed -E -n -u -e 's/data: (\{.*)/\1/gp' | "${JQ[@]}" | tee -- "$TEE" | "${MDPAGER[@]}"
printf -- '\n' >&2
hr '<'
