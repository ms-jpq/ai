#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../..")"
VAR="$ROOT/var"

if [[ $PWD == "$HOME" ]]; then
  cd -- "$ROOT"
  exec -- "$0" "$@"
fi

SANDBOX=(
  ~/.local/libexec/sandbox/libexec/dispatch.sh
  --auth
  --network
)

if [[ $OSTYPE == darwin* ]]; then
  SANDBOX+=(--path '/Users' --path "$HOME" --path "$HOME/.local" --path "$HOME/.local/opt" --path '/var/folders' --path '/tmp')
fi

if CWD="$(~/.local/libexec/dnif.sh "$PWD" '.git' | tac | grep -E --max-count 1 -e '.')" && [[ $CWD != "$PWD" ]]; then
  SANDBOX+=(--dir "$CWD:rw")
fi

SANDBOX+=(
  --dir "$ROOT"
  --dir "$ROOT/opt/codex/profiles:rw"
  --dir "$VAR:rw"
)

unset -- SHELL VISUAL
export -- PATH="$ROOT/opt/codex/bin:$PATH" BASH_ENV="$ROOT/opt/libexec/bash-env.sh"
export -- PAGER=tee
exec -- ~/.local/libexec/supernice.sh "${SANDBOX[@]}" -- ~/.local/bin/hp "$@"
