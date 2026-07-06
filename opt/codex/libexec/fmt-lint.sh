#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FILE_PATH="$*"

# shellcheck disable=SC2154,SC2094
if FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$FILE_PATH" < "$FILE_PATH")"; then
  sponge -- "$FILE_PATH" <<< "$FMT"
fi

case "$FILE_PATH" in
*.sh | *.bash)
  if command -v -- shellcheck > /dev/null; then
    shellcheck --shell=bash -- "$FILE_PATH"
  fi
  ;;
*)
  ;;
esac
