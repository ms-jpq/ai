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

SANDBOX=(
  ~/.local/opt/sandbox/libexec/dispatch.sh
  --auth
  --network
)

if CWD="$(~/.local/libexec/dnif.sh "$PWD" '.git' | tac | grep -E --max-count 1 -e '.')" && [[ $CWD != "$PWD" ]]; then
  SANDBOX+=(--dir "$CWD:rw")
fi

SANDBOX+=(
  --dir "$ROOT"
  --dir "$VAR:rw"
)

exec -- nice -n 19 -- "${SANDBOX[@]}" -- ~/.local/bin/hp "$@"
