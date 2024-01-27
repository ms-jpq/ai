#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TMP="$1"
TEE="${2:-"/dev/null"}"

CURL=(
  "${0%/*}/llm-curl.sh"
  --write-out '%{http_code}'
  --output "$TMP"
  --data @-
  -- 'https://api.openai.com/v1/chat/completions'
)

hr() {
  {
    printf -- '\n'
    "${0%/*}/hr.sh" "$@"
    printf -- '\n'
  } >&2
}

hr '?'
CODE="$(RECURSION=1 "${CURL[@]}")"

if ((CODE != 200)); then
  jq <"$TMP" || cat -- "$TMP"
else
  jq --exit-status --raw-output '.choices[].message.content' <"$TMP" | tee -- "$TEE" | glow
fi
printf -- '\n' >&2
hr '^'
