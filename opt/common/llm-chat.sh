#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ROOT="${0%/*}/../.."
ARGV=("$@")

NAME="$1"
CHAT_CLIENT="$2"
CHAT_STREAMING="$3"
CHAT_PROMPT="$4"
shift -- 4

CHAT_HISTORY="${CHAT_HISTORY:-"$(nljson-ledger.sh "$NAME" '')"}"
CHAT_TMP="${CHAT_TMP:-"$(mktemp -p "${CHAT_HISTORY%/*}" -- 'XXXXXXXX.md')"}"
export -- CHAT_HISTORY CHAT_TMP

JQ_SC=(jq --exit-status --slurp --compact-output)
# shellcheck disable=SC2016
JQ_APPEND=(
  "${JQ_SC[@]}"
  --raw-input
  '{ role: $role, content: . }'
  --arg role
)
# shellcheck disable=SC2016
JQ_SEND=(
  "${JQ_SC[@]}"
  "$@"
  "$CHAT_HISTORY"
)

if ! [[ -s $CHAT_HISTORY ]]; then
  SYS="$(prompt.sh "$NAME-system" red "$CHAT_PROMPT")"
  if [[ -n $SYS ]]; then
    printf -- '%s' "$SYS" | tee -- /dev/stderr | "${JQ_APPEND[@]}" 'system' >> "$CHAT_HISTORY"
    printf -- '\n'
  fi
  hr.sh '!'
fi >&2

REEXEC=0
if [[ -t 0 ]]; then
  USR="$(readline.sh green "$NAME-user")"
  if [[ -z $USR ]]; then
    REEXEC=1
  fi

  read -r -- LINE <<< "$USR"
  PRINT=1
  case "$LINE" in
  '>c' | '>cls')
    REEXEC=1
    clear
    ;;
  '>die')
    PREV="$CHAT_HISTORY"
    CHAT_HISTORY="$(nljson-ledger.sh "$NAME" '')"
    if ! [[ -v CHAT_DIEHARD ]]; then
      sed -E -n -e '1p' -- "$PREV" > "$CHAT_HISTORY"
    fi
    REEXEC=1
    ;;
  '>u' | '>undo')
    for _ in {1..2}; do
      sed -E -e '$d' -i -- "$CHAT_HISTORY"
    done
    REEXEC=1
    ;;
  '>e' | '>edit')
    jq --raw-output '["# >>> \(.role) <<<", "", .content, "", "---", ""][]' < "$CHAT_HISTORY" | "$ROOT/node_modules/.bin/prettier" --stdin-filepath='-.md' > "$CHAT_TMP"
    # shellcheck disable=2154
    "$EDITOR" -- "$CHAT_TMP"
    REEXEC=1
    ;;
  *)
    PRINT=0
    ;;
  esac
  if ((PRINT)); then
    printf -- '%q\n' "$LINE" >&2
  fi
else
  USR="$(< /dev/stdin)"
fi

if ((REEXEC)); then
  exec -- "$0" "${ARGV[@]}"
fi

"${JQ_APPEND[@]}" user <<< "$USR" >> "$CHAT_HISTORY"

{
  SHORT_HIST="~${CHAT_HISTORY#"$HOME"}"
  printf -v JQ_HIST -- '%q ' jq '.' "$SHORT_HIST"
  JQ_HIST="${JQ_HIST//'. \~'/'. ~'}"
  printf -- '\n%s\n' "$JQ_HIST"
} >&2

"${JQ_SEND[@]}" | "$CHAT_CLIENT" "$CHAT_STREAMING" | "${JQ_APPEND[@]}" 'assistant' >> "$CHAT_HISTORY"

if [[ -t 0 ]]; then
  exec -- "$0" "${ARGV[@]}"
fi
