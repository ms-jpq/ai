#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../..")"
VAR="$ROOT/var"

if [[ $PWD == "$HOME" ]]; then
  cd -- "$ROOT"
  exec -- "$@"
fi

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

SHELL="$(command -v -- bash)"
export -- SHELL
exec -- nice -n 19 -- "${OOM[@]}" "${SANDBOX[@]}" -- ~/.local/bin/hp "$@"
