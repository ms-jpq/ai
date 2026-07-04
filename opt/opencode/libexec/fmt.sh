#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FILE="$1"

# shellcheck disable=SC2154,SC2094
if FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$FILE" < "$FILE")"; then
  sponge -- "$FILE" <<< "$FMT"
fi
