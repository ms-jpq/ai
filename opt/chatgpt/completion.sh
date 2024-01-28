#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TEE="$*"
CURL=(
  curl.sh
  --data @-
  -- 'https://api.openai.com/v1/chat/completions'
)

hr() {
  {
    printf -- '\n'
    hr.sh "$@"
    printf -- '\n'
  } >&2
}

hr '?'
if ! OUT="$("${CURL[@]}")"; then
  {
    jq <<<"$OUT" || printf -- '%s\n' "$OUT"
  } >&2
else
  jq --exit-status --raw-output '.choices[].message.content' <<<"$OUT" | tee -- "$TEE" | glow
fi
printf -- '\n' >&2
hr '^'
