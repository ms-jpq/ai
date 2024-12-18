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
[
  (.sources[] | [
    "# # \(.metadata.title | gsub("\\s+"; " ") | @html)",
    "## [➜](\(.metadata.url | @html))",
    .pageContent | @html
  ] | join("\n")),
  "\n---\n",
  .message
] | join("\n")
JQ

PARSE=(
  jq
  --exit-status
  --raw-output
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
