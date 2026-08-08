#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FILE_PATH="$*"
BASE="${0%/*}"
STAT=(stat --format='%d:%i:%y:%s' -- "$FILE_PATH")

for TRY in 2 1 0; do
  BEFORE="$("${STAT[@]}")"

  # shellcheck disable=SC2154,SC2094
  FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$FILE_PATH" < "$FILE_PATH")"

  AFTER="$("${STAT[@]}")"
  if [[ $BEFORE == "$AFTER" ]]; then
    sponge -- "$FILE_PATH" <<< "$FMT"
    break
  fi

  if ! ((TRY)); then
    sleep -- 1
  fi
done

case "$FILE_PATH" in
*.md)
  "$BASE/../lint.d/slop-cop.sh" "$FILE_PATH"
  ;;
*.json | *.yml | *.yaml | *.toml)
  ;;
*.sh | *.bash)
  if command -v -- shellcheck > /dev/null; then
    shellcheck -- "$FILE_PATH"
  fi
  ;;
*)
  ;;
esac
