#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

INSTANCE="$1"
DATA="$(realpath -- "${0%/*}")"
RECORDS="$(realpath -- "$DATA/records")"
VERSIONS="$RECORDS/$INSTANCE"

mkdir -p -- "$VERSIONS"
for DEPENDENCY in "$DATA/inbox/"*; do
  if [[ -L $DEPENDENCY ]]; then
    AVAILABLE=0
    for INPUT in "$DEPENDENCY/"*/latest; do
      if [[ -L $INPUT ]]; then
        [[ -d $INPUT/output ]]
        [[ $(< "$INPUT/output/exit_status") == 0 ]]
        AVAILABLE=1
      fi
    done
    ((AVAILABLE))
  fi
done

REVISION="$(mktemp -d -- "$VERSIONS/XXXXXXXXXX")"
mkdir -- "$REVISION/input" "$REVISION/output"
ln -sTnf -- "$REVISION/output" "$DATA/outbox"
cp --archive -- "$DATA/inbox/." "$REVISION/input/"
cd -- "$REVISION"

if "$DATA/command" "$@" > output/stdout; then
  STATUS=0
else
  STATUS="$?"
fi
printf -- '%s\n' "$STATUS" > output/exit_status
if ((STATUS != 0)); then
  exit "$STATUS"
fi

ln -s -- "${REVISION##*/}" "$REVISION/.latest"
mv --force --no-target-directory -- "$REVISION/.latest" "$VERSIONS/latest"
