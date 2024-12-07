#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='f:'
LONG_OPTS='file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

SELF="${0##*/}"
ARGV=("$@")

while (($#)); do
  case "$1" in
  -f | --file)
    GPT_HISTORY="$(nljson-ledger.sh 'perplexica' "$2")"
    shift -- 2
    ;;
  --)
    shift -- 1
    break
    ;;
  *)
    exit 1
    ;;
  esac
done

GPT_HISTORY="${GPT_HISTORY:-"$(nljson-ledger.sh 'perplexica' '')"}"
GPT_TMP="${GPT_TMP:-"$(mktemp)"}"
export -- "${GPT_LVL:-0}" GPT_SYS="${GPT_SYS:-""}"
export -- GPT_HISTORY GPT_STREAMING GPT_TMP

JQ_SC=(jq --exit-status --slurp --compact-output)
# shellcheck disable=SC2016
JQ_APPEND=(
  "${JQ_SC[@]}"
  --raw-input
  '[$role, .]'
  --arg role
)
# shellcheck disable=SC2016
JQ_SEND=(
  "${JQ_SC[@]}"
  '{ stream: true, model: $model, max_tokens: $tokens, messages: .[1:], system: .[0].content }'
  "$GPT_HISTORY"
)

if ! [[ -s $GPT_HISTORY ]]; then
  GPT_SYS="$(prompt.sh "$SELF-system" red "$@")"
  if [[ -n $GPT_SYS ]]; then
    printf -- '%s' "$GPT_SYS"
    printf -- '\n'
  fi
  hr.sh '!'
else
  GPT_SYS="${GPT_SYS:-""}"
fi >&2

REEXEC=0
if [[ -t 0 ]]; then
  USR="$(readline.sh green "$SELF-user")"
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
    GPT_HISTORY="$(nljson-ledger.sh 'perplexica' '')"
    REEXEC=1
    ;;
  '>undo')
    for _ in {1..2}; do
      sed -E -e '$d' -i -- "$GPT_HISTORY"
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

"${JQ_APPEND[@]}" <<< "$USR" user >> "$GPT_HISTORY"

{
  printf -v JQHIST -- '%q ' jq '.' "$GPT_HISTORY"
  printf -- '\n%s\n' "$JQHIST"
} >&2

"${JQ_SEND[@]}" --arg system "$GPT_SYS" | completion.sh 0 "$GPT_TMP"
"${JQ_APPEND[@]}" 'assistant' < "$GPT_TMP" >> "$GPT_HISTORY"

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
