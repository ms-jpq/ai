#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TARGET="$1"
MESSAGE="$2"

if ! [[ -e $TARGET ]]; then
  exit
fi

RESOLVED="$(realpath -- "$TARGET")"
if [[ -d $RESOLVED ]]; then
  DIR="$RESOLVED"
else
  DIR="${RESOLVED%/*}"
fi

TOP="$(git -C "$DIR" rev-parse --show-toplevel)"

git -C "$TOP" add -A
if STATUS="$(git -C "$TOP" status --porcelain)" && [[ -n $STATUS ]]; then
  git -C "$TOP" commit -q -m "$MESSAGE"
fi
