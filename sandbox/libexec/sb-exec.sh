#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS=''
LONG_OPTS='path:,network:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

while true; do
  case "$1" in
  --path)
    shift -- 1
    ;;
  --network)
    shift -- 1
    ;;
  --)
    shift -- 1
    break
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
done

ROOT="$(realpath -- "${0%/*}/..")"

# shellcheck disable=SC2154
ARGV=(
  sandbox-exec
  -D PROFILES="$ROOT/darwin"
  -D TMPDIR="$TMPDIR"
  -D HOME="$HOME"
  -D CWD="$PWD"
  -D SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
)

exec -- "${ARGV[@]}" -- "$@"
