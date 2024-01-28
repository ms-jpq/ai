#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ETC="${0%/*}/../../etc"
CURL=(
  curl
  --config "$ETC/curlrc"
  --no-progress-meter
)

if [[ -z "$*" ]]; then
  exec -- xargs -- "$0"
fi

printf -- '%s\n' "$*" >&2
"${CURL[@]}" -- "$*" | read-html.js | llm-su.sh -- "$ETC/prompts/news.txt"
