#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='s,t:'
LONG_OPTS='stream,tee:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

SELF="${0##*/}"
BASE="${0%/*}/../.."
TMPDIR="$BASE/var/chatgpt"

ARGV=("$@")
MODEL="$(<"$BASE/etc/openai/model")"

mkdir -v -p -- "$TMPDIR" >&2
GPT_HISTORY="${GPT_HISTORY:-"$TMPDIR/$(date --utc -Iseconds).json"}"
GPT_LVL="${GPT_LVL:-0}"
export -- GPT_HISTORY GPT_LVL

while (($#)); do
  case "$1" in
  -s | --stream)
    STREAMING=1
    shift -- 1
    ;;
  -t | --tee)
    TEE="$2"
    mkdir -v -p -- "$TEE" >&2
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

# shellcheck disable=SC2016
JQ_APPEND=(
  jq
  --exit-status
  --raw-input
  --slurp
  --compact-output
  '{ role: $role, content: . }'
  --arg role
)
# shellcheck disable=SC2016
JQ_SEND=(
  jq
  --exit-status
  --slurp
  --arg model "$MODEL"
  --compact-output
  '{ stream: true, model: $model, messages: . }'
  "$GPT_HISTORY"
)

if ! [[ -s "$GPT_HISTORY" ]]; then
  if [[ -v TEE ]]; then
    TX="$TEE/->.txt"
  else
    TX='/dev/null'
  fi
  SYS="$(prompt.sh "$SELF-system" red "$@")"
  if [[ -n "$SYS" ]]; then
    printf -- '%s' "$SYS" | tee -- /dev/stderr "$TX" | "${JQ_APPEND[@]}" system >>"$GPT_HISTORY"
    printf -- '\n' >&2
  fi
  hr.sh '>'
fi

if [[ -v TEE ]]; then
  TX="$TEE/$GPT_LVL.tx.txt"
  RX="$TEE/$GPT_LVL.rx.md"
else
  TX='/dev/null'
  RX="$TX"
fi

REEXEC=0
if [[ -t 0 ]]; then
  USR="$(readline.sh green "$SELF-user")"
  if [[ -z "$USR" ]]; then
    REEXEC=1
  fi
  read -r -- LINE <<<"$USR"
  case "$LINE" in
  '>exit')
    exit 0
    ;;
  '>cls')
    REEXEC=1
    clear
    ;;
  '>die')
    REEXEC=1
    sed -E -e '1!d' -i -- "$GPT_HISTORY"
    ;;
  '>diehard')
    REEXEC=1
    rm -v -fr -- "$GPT_HISTORY"
    ;;
  '>redo')
    sed -E -e '$d' -i -- "$GPT_HISTORY"
    REEXEC=1
    ;;
  *) ;;
  esac
else
  USR="$(</dev/stdin)"
fi

if ((REEXEC)); then
  exec -- "$0" "${ARGV[@]}"
fi

tee -- "$TX" <<<"$USR" | "${JQ_APPEND[@]}" user >>"$GPT_HISTORY"

{
  printf -v JQHIST -- '%q ' jq '.' "$GPT_HISTORY"
  printf -- '\n%s\n' "$JQHIST"
} >&2

"${JQ_SEND[@]}" | completion.sh "${STREAMING:-0}" "$RX"

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
