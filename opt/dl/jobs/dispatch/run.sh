#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
cd -P -- "$1"
shift -- 1
STEP="$PWD"

"${SELF%/*}/data/list-dependencies" --plain "$STEP" 1 | while IFS= read -r DEPENDENCY; do
  if ! [[ -f wants/$DEPENDENCY/outbox/stdout ]]; then
    printf -- 'Missing dependency output: %s\n' "$STEP/wants/$DEPENDENCY/outbox/stdout" >&2
    exit 1
  fi
done

mkdir -p -- outbox
OUTPUT="$(mktemp -- "$STEP/outbox/.stdout.XXXXXX")"
trap 'rm -f -- "$OUTPUT"' EXIT

s6-envdir -- env ./run.sh "$@" > "$OUTPUT"
mv --force --no-target-directory -- "$OUTPUT" outbox/stdout
