#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if [[ $PWD == "$HOME" ]]; then
  TMP="$(mktemp -d)"
  cd -- "$TMP"
  exec -- "$@"
fi

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../..")"
VAR="$ROOT/var"

OOM=()
case "$OSTYPE" in
linux*)
  OOM+=(
    choom
    --adjust 1000
    --
  )
  ;;
*)
  ;;
esac

SANDBOX=(
  ~/.local/opt/sandbox/libexec/dispatch.sh
  --auth
  --network
)

if CWD="$(~/.local/libexec/dnif.sh "$PWD" '.git' | tac | grep -E --max-count 1 -e '.')" && [[ $CWD != "$PWD" ]]; then
  SANDBOX+=(--dir "$CWD:rw")
fi

LIB="$HOME/Library"
SANDBOX+=(
  --dir "$ROOT"
  --dir "$VAR:rw"
  --dir "$LIB/Application Support/opencode:rw"
)

export -- BASH_ENV="$ROOT/opt/libexec/bash-env.sh"
exec -- nice -n 19 -- "${OOM[@]}" "${SANDBOX[@]}" -- ~/.local/bin/hp "$@"
