#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

INSTANCE="$1"
DATA="$(realpath -- "${0%/*}")"
OUTBOX="$(realpath -- "$DATA/outbox")"
VERSIONS="$OUTBOX/.versions/$INSTANCE"

mkdir -p -- "$VERSIONS"
ln -sTnf -- "$VERSIONS" "$DATA/versions"
REVISION="$(mktemp -d -- "$VERSIONS/XXXXXXXXXX")"
mkdir -- "$REVISION/meta"

"$DATA/command" "$@" > "$REVISION/stdout"

ln -s -- "${REVISION##*/}" "$REVISION/.latest"
mv --force --no-target-directory -- "$REVISION/.latest" "$VERSIONS/latest"
ln -s -- ".versions/$INSTANCE/latest" "$REVISION/.outbox"
mv --force --no-target-directory -- "$REVISION/.outbox" "$OUTBOX/$INSTANCE"
