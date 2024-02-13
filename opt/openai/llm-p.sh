#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

cd -- "${0%/*}/../../etc/prompts"
NAME="$*"
if [[ -z "$NAME" ]]; then
  printf -v PREVIEW -- '%q ' cat --
  NAME="$(printf -- '%s\0' ./*.txt | fzf --read0 --preview="$PREVIEW {}")"
else
  NAME="./$NAME.txt"
fi

exec -- edit.sh "$NAME"
