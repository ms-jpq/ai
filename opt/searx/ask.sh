#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"
COMMON="$BASE/../common"

set -a
# shellcheck disable=SC1091
source -- "$BASE/../../.env"
set +a

QUESTION="$("$COMMON/readline.sh" "yellow" "${0##*/}")"
QUERY="$(jq --raw-input --raw-output '@uri' <<< "$QUESTION")"
CURL=(
  "$COMMON/curl.sh"
  'searx'
  --connect-timeout 6
  --no-buffer
)

read -r -d '' -- JQ <<- 'JQ' || true
.results[]
| [
  "# # \(.title | gsub("\\s+"; " ") | @html)",
  "## [➜](\(.url | @html))",
  .content | @html
  ] | join("\n")
JQ
J=(jq --unbuffered --raw-output "$JQ")

CODE=0
for N in {1..3}; do
  {
    # shellcheck disable=SC2154
    "${CURL[@]}" -- "$SEARX_URI/search?format=json&pageno=$N&q=$QUERY" | "${J[@]}"
    printf -- '\n---\n'
  } | "$COMMON/md-pager.sh" 0
done | less || CODE=$?

if ((CODE == 141)); then
  CODE=0
fi

exit "$CODE"
