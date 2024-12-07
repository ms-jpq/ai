#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
ROOT="${BASE%/*}/../.."
export -- CURL_HOME="$ROOT/libexec"

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

QUESTION="$("$CURL_HOME/readline.sh" "yellow" "${0##*/}")"
QUERY="$(jq --raw-input --raw-output '@uri' <<< "$QUESTION")"
CURL=(
  curl
  --connect-timeout 6
  --no-buffer
)

COLS="$(tput -- cols)"
COLS=$((COLS - 4))
PAGE=(glow --config /dev/null --style pink --width "$COLS")

read -r -d '' -- JQ <<- 'JQ' || true
.results[] | "# # \(.title | gsub("\\s+"; " ") | @html)\n## [➜](\(.url | @html))\n\(.content | @html)"
JQ
J=(jq --unbuffered --raw-output "$JQ")

CODE=0
for N in {1..3}; do
  {
    # shellcheck disable=SC2154
    "${CURL[@]}" -- "$SEARX_URI/search?format=json&pageno=$N&q=$QUERY" | "${J[@]}"
    printf -- '\n---\n'
  } | CLICOLOR_FORCE=1 COLORTERM=truecolor "${PAGE[@]}"
done | less || CODE=$?

if ((CODE)) && ((CODE != 141)); then
  exit "$CODE"
else
  exec -- "$0" "$@"
fi
