#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ACTION="$1"
shift -- 1

case "$ACTION" in
compile | deliver)
  :
  ;;
*)
  set -x
  exit 2
  ;;
esac
