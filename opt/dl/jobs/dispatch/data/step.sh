#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

INSTANCE="$1"
DATA="$(realpath -- "${0%/*}")"
RECORDS="$(realpath -- "$DATA/records")"
VERSIONS="$RECORDS/.versions/$INSTANCE"

mkdir -p -- "$VERSIONS"
ln -sTnf -- "$VERSIONS/latest/output" "$DATA/outbox"
for INPUT in "$DATA/inbox/"*; do
  if [[ -L $INPUT ]]; then
    [[ -d $INPUT/output ]]
    [[ $(< "$INPUT/output/exit_status") == 0 ]]
  fi
done

REVISION="$(mktemp -d -- "$VERSIONS/XXXXXXXXXX")"
mkdir -- "$REVISION/input" "$REVISION/output"
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
ln -s -- ".versions/$INSTANCE/latest" "$REVISION/.outbox"
mv --force --no-target-directory -- "$REVISION/.outbox" "$RECORDS/$INSTANCE"
