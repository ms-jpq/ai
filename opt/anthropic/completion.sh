#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STREAMING="$1"
TEE="$2"

CURL=(
  curl.sh
  --data-binary @-
  --no-buffer
  -- 'https://api.anthropic.com/v1/messages'
)
JQ=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.content_block // .delta // {} | .text // ""'
)

if ! [[ -v MDPAGER ]]; then
  if ((STREAMING)); then
    MPAGER=(tee --)
  else
    MPAGER=(
      bat
      --style plain
      --paging never
      --language markdown
      -- -
    )
  fi
else
  # shellcheck disable=SC2206
  MPAGER=($MDPAGER)
fi

hr() {
  {
    printf -- '\n'
    hr.sh "$@"
    printf -- '\n'
  } >&2
}

hr '>'
"${CURL[@]}" | sed -E -n -u -e 's/^data:[[:space:]]+(\{.*)/\1/gp' | "${JQ[@]}" | tee -- "$TEE" | "${MPAGER[@]}" >&2
printf -- '\n' >&2
hr '<'
