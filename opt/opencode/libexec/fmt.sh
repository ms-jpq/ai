#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s nullglob extglob globstar

FILE="$1"

# shellcheck disable=SC2154,SC2094
if FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$FILE" < "$FILE")"; then
  sponge -- "$FILE" <<< "$FMT"
fi
