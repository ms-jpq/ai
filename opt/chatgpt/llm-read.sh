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

while read -r -d '' -- LINE; do
  URI="${NEWS_PROXY:-""}$LINE"
  printf -- '%s\n' "$URI" >&2

  "${CURL[@]}" -- "$URI" | read-html.js | llm-su.sh "${ARGV[@]}"
done
