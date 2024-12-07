#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='s:,t:,f:'
LONG_OPTS='stream:,tee:,file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

SELF="${0##*/}"
DIR="${0%/*}"
BASE="$DIR/../.."
ARGV=("$@")
MODEL="$(< "$BASE/etc/anthropic/model")"
TOKENS="$(< "$BASE/etc/anthropic/max_tokens")"

while (($#)); do
  case "$1" in
  -s | --stream)
    GPT_STREAMING="${GPT_STREAMING:-"$2"}"
    shift -- 1
    ;;
  -t | --tee)
    TEE="$2"
    mkdir -v -p -- "$TEE" >&2
    shift -- 2
    ;;
  -f | --file)
    GPT_HISTORY="$(nljson-ledger.sh 'claudy' "$2")"
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

GPT_HISTORY="${GPT_HISTORY:-"$(nljson-ledger.sh 'claudy' '')"}"
GPT_TMP="${GPT_TMP:-"$(mktemp)"}"
GPT_LVL="${GPT_LVL:-0}"
export -- GPT_HISTORY GPT_LVL GPT_STREAMING GPT_TMP GPT_SYS
touch -- "$GPT_HISTORY"

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
  --arg model "$MODEL"
  --argjson tokens "$TOKENS"
  '{ stream: true, model: $model, max_tokens: $tokens, messages: ., system: (if $system == "" then [] else $system end) }'
  "$GPT_HISTORY"
)
JQ_RECV=(
  "${JQ_SC[@]}"
  --raw-input
  '{ role: "assistant", content: . }'
)

if ! [[ -s $GPT_HISTORY ]]; then
  if [[ -v TEE ]]; then
    TX="$TEE/->.txt"
  else
    TX='/dev/null'
  fi
  GPT_SYS="$(prompt.sh "$SELF-system" red "$@")"
  if [[ -n $GPT_SYS ]]; then
    printf -- '%s' "$GPT_SYS" | tee -- "$TX" >&2
    printf -- '\n' >&2
  fi
  hr.sh '!' >&2
else
  GPT_SYS="${GPT_SYS:-""}"
fi

if [[ -v TEE ]]; then
  TX="$TEE/$GPT_LVL.tx.txt"
  RX="$TEE/$GPT_LVL.rx.md"
else
  TX='/dev/null'
  RX="$GPT_TMP"
fi

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
    GPT_HISTORY="$(nljson-ledger.sh 'claudy' '')"
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

tee -- "$TX" <<< "$USR" | "${JQ_APPEND[@]}" user >> "$GPT_HISTORY"

{
  printf -v JQHIST -- '%q ' jq '.' "$GPT_HISTORY"
  printf -- '\n%s\n' "$JQHIST"
} >&2

"${JQ_SEND[@]}" --arg system "$GPT_SYS" | completion.sh "${GPT_STREAMING:-2}" "$RX"
"${JQ_RECV[@]}" < "$RX" >> "$GPT_HISTORY"

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
