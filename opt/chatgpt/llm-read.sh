#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}/../.."
ENV="$BASE/.env"
ETC="$BASE/etc"
CURL=(
  curl
  --config "$ETC/curlrc"
  --no-progress-meter
)

if [[ -z "$*" ]]; then
  exec -- xargs -- "$0"
fi

touch -- "$ENV"
set -a
# shellcheck disable=SC1090
source -- "$ENV"
set +a

URI="${NEWS_PROXY:-""}$*"

printf -- '%s\n' "$URI" >&2

"${CURL[@]}" -- "$URI" | read-html.js | llm-su.sh -- "$ETC/prompts/news.txt"
