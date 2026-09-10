#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../..")"
VAR="$ROOT/var"

if [[ $PWD == "$HOME" ]]; then
  cd -- "$ROOT"
  exec -- "$0" "$@"
fi

case "$OSTYPE" in
linux*)
  OOM=(
    choom
    --adjust 1000
    --
  )
  ;;
*)
  OOM=()
  ;;
esac

SANDBOX=(
  ~/.local/libexec/sandbox/libexec/dispatch.sh
  --auth
  --network
)

if CWD="$(~/.local/libexec/dnif.sh "$PWD" '.git' | tac | grep -E --max-count 1 -e '.')" && [[ $CWD != "$PWD" ]]; then
  SANDBOX+=(--dir "$CWD:rw")
fi

SANDBOX+=(
  --dir "$ROOT"
  --dir "$ROOT/opt/codex/profiles:rw"
  --dir "$VAR:rw"
)

unset -- SHELL
export -- PATH="$ROOT/opt/codex/bin:$PATH" BASH_ENV="$ROOT/opt/libexec/bash-env.sh"
export -- PAGER=tee
exec -- nice -n 19 -- "${OOM[@]}" "${SANDBOX[@]}" -- ~/.local/bin/hp "$@"
