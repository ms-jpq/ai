#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if INDEX="$("${0%/*}/../hooks/session-file.sh" "$PWD")"; then
  rm -fr -- "$INDEX"
fi
