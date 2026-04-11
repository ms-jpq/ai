#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

if [[ $PWD == "$HOME" ]]; then
  TMP="$(mktemp -d)"
  cd -- "$TMP"
  exec -- "$0" "$@"
fi

BASE="$(realpath -- "$0")"
BASE="${BASE%/*}"
PATH="$BASE/bin:$PATH"
ROOT="$BASE/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

case "$OSTYPE" in
darwin*)
  CC='/opt/homebrew/bin/claude'
  ;;
linux*)
  CC='/usr/bin/claude-code'
  ;;
*)
  exit 2
  ;;
esac

export -- CLAUDE_CONFIG_DIR="$ROOT/var/claude"

COLOURS=(blue green yellow purple orange pink cyan)
RANDOM_COLOR="${COLOURS[RANDOM%${#COLOURS[@]}]}"

ARGV=("$@")
if ! (($#)) && INDEX="$("$BASE/libexec/session-file.sh" "$PWD")" && [[ -s $INDEX ]]; then
  SESSION="$(< "$INDEX")"
  DIR="$(sed -E -e 's#[^[:alnum:]]#-#g' <<< "$PWD")"
  JSONL="$ROOT/var/claude/projects/$DIR/$SESSION.jsonl"

  if [[ -f $JSONL ]]; then
    ARGV+=(--resume "$SESSION")
  fi
fi

if [[ ${ARGV[*]} == '-' ]]; then
  RANDOM_COLOR='default'
  ARGV=()
fi

for PLUGIN in "$BASE/local-plugins"/*/; do
  ARGV+=(--plugin-dir "$PLUGIN")
done

clear -x
printf -- '%s' "/color $RANDOM_COLOR" | ~/.local/bin/hp "$CC" "${ARGV[@]}"
