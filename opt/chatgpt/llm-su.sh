#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='t:'
LONG_OPTS='tee:'
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
  --)
    shift -- 1
    break
    ;;
  -t | --tee)
    TEE="$2"
    mkdir -v -p -- "$TEE" >&2
    shift -- 2
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
  '{ role: $role, content: . }'
  --arg role
)
# shellcheck disable=SC2016
JQ_SEND=(
  jq
  --exit-status
  --slurp
  --arg model "$MODEL"
  '{ model: $model, messages: . }'
  "$GPT_HISTORY"
)

if ! [[ -s "$GPT_HISTORY" ]]; then
  if [[ -v TEE ]]; then
    TX="$TEE/->.txt"
  else
    TX='/dev/null'
  fi
  SYS="$(prompt.sh "$SELF-system" red "$@")"
  printf -- '%s' "$SYS" | tee -- /dev/stderr "$TX" | "${JQ_APPEND[@]}" system >>"$GPT_HISTORY"
  printf -- '\n' >&2
  hr.sh '>'
fi

if [[ -v TEE ]]; then
  TX="$TEE/$GPT_LVL.tx.txt"
  RX="$TEE/$GPT_LVL.rx.md"
else
  TX='/dev/null'
  RX="$TX"
fi

if [[ -t 0 ]]; then
  readline.sh green "$SELF-user"
else
  cat --
fi | tee -- "$TX" | "${JQ_APPEND[@]}" user >>"$GPT_HISTORY"

{
  printf -v JQHIST -- '%q ' jq '.' "$GPT_HISTORY"
  printf -- '\n%s\n' "$JQHIST"
} >&2

"${JQ_SEND[@]}" | completion.sh "$RX"

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
