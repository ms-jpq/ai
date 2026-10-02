#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

RECORDS="$(realpath -- "$1")"
NOW="$(date +%s)"

for INSTANCE in "$RECORDS/.versions/"*; do
  if [[ -d $INSTANCE ]] && ! [[ -L $INSTANCE ]]; then
    find "$INSTANCE" -mindepth 3 -maxdepth 3 -type f -path '*/output/exit_status' -printf '%T@ %h\0' \
      | LC_ALL=C sort --zero-terminated --numeric-sort --reverse \
      | tail --zero-terminated --lines=+3 \
      | while IFS= read -r -d '' ENTRY; do
        COMPLETED="${ENTRY%% *}"
        OUTPUT="${ENTRY#* }"
        REVISION="${OUTPUT%/output}"
        if ((NOW - ${COMPLETED%.*} >= 1800)) && ! [[ $REVISION -ef $INSTANCE/latest ]]; then
          rm -fr -- "$REVISION"
        fi
      done
  fi
done
