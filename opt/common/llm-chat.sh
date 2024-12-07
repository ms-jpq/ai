#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ARGV=("$@")

NAME="$1"
CHAT_CLIENT="$2"
CHAT_STREAMING="$3"
CHAT_TEE="$4"
CHAT_PROMPT="$5"
shift -- 5

CHAT_HISTORY="${CHAT_HISTORY:-"$(nljson-ledger.sh "$NAME" '')"}"
CHAT_TMP="${CHAT_TMP:-"$(mktemp -p "${CHAT_HISTORY%/*}")"}"
export -- CHAT_LVL="${CHAT_LVL:-0}"
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
  if [[ -v CHAT_TEE ]]; then
    TX="$CHAT_TEE/->.txt"
  else
    TX='/dev/null'
  fi
  SYS="$(prompt.sh "$NAME-system" red "$CHAT_PROMPT")"
  if [[ -n $SYS ]]; then
    printf -- '%s' "$SYS" | tee -- /dev/stderr "$TX" | "${JQ_APPEND[@]}" 'system' >> "$CHAT_HISTORY"
    printf -- '\n'
  fi
  hr.sh '!'
fi >&2

if [[ -v CHAT_TEE ]]; then
  TX="$CHAT_TEE/$CHAT_LVL.tx.txt"
  RX="$CHAT_TEE/$CHAT_LVL.rx.md"
else
  TX='/dev/null'
  RX="$CHAT_TMP"
fi

REEXEC=0
if [[ -t 0 ]]; then
  USR="$(readline.sh green "$NAME-user")"
  if [[ -z $USR ]]; then
    REEXEC=1
  fi

  read -r -- LINE <<< "$USR"
  PRINT=1
  case "$LINE" in
  '>cls' | '>clear')
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
  '>undo')
    for _ in {1..2}; do
      sed -E -e '$d' -i -- "$CHAT_HISTORY"
    done
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

tee -- "$TX" <<< "$USR" | "${JQ_APPEND[@]}" user >> "$CHAT_HISTORY"

{
  printf -v JQ_HIST -- '%q ' jq '.' "$CHAT_HISTORY"
  printf -- '\n%s\n' "$JQ_HIST"
} >&2

"${JQ_SEND[@]}" | "$CHAT_CLIENT" "$CHAT_STREAMING" "$RX"
"${JQ_APPEND[@]}" 'assistant' < "$RX" >> "$CHAT_HISTORY"

if [[ -t 0 ]]; then
  ((++CHAT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
