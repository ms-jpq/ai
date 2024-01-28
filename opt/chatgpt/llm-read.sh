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

touch -- "$ENV"
set -a
# shellcheck disable=SC1090
source -- "$ENV"
set +a

if (($#)); then
  ARGV=("$@")
else
  ARGV=('read')
fi

URI="${NEWS_PROXY:-""}$(</dev/stdin)"
printf -- '%s\n' "$URI" >&2
"${CURL[@]}" -- "$URI" | read-html.js | tee -- /dev/stderr | llm-su.sh "${ARGV[@]}"
