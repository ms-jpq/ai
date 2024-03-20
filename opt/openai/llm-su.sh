#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='g,s,t:,f:'
LONG_OPTS='gay,stream,tee:,file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

SELF="${0##*/}"
DIR="${0%/*}"
BASE="$DIR/../.."
ARGV=("$@")
TMPDIR="$BASE/var/chatgpt"
MODEL="$(<"$BASE/etc/openai/model")"

if ! [[ -v PATHMOD ]]; then
  PATH="$BASE/libexec:$DIR:$PATH"
  export -- PATHMOD=1
fi

clean() {
  for F in "$TMPDIR"/*.json; do
    if ! [[ -s "$F" ]]; then
      printf -- '%s\0' "$F"
    fi
  done | xargs -0 -r -- rm -v -f --
}

if ! ((RANDOM % 16)); then
  clean
fi

while (($#)); do
  case "$1" in
  -g | --gay)
    printf -v MDPAGER -- '%q ' "$BASE/.venv/bin/gay" '--unbuffered'
    shift -- 1
    ;;
  -s | --stream)
    GPT_STREAMING="${GPT_STREAMING:-1}"
    shift -- 1
    ;;
  -t | --tee)
    TEE="$2"
    mkdir -v -p -- "$TEE" >&2
    shift -- 2
    ;;
  -f | --file)
    if [[ -z "${GPT_HISTORY:-""}" ]]; then
      clean
      case "$2" in
      -) ;;
      !)
        printf -v PREVIEW -- '%q ' jq --sort-keys --color-output .
        GPT_HISTORY="$(printf -- '%s\0' "$TMPDIR"/*.json | fzf --read0 --preview="$PREVIEW {}")"
        ;;
      @)
        FILES=("$TMPDIR"/*.json)
        GPT_HISTORY="${FILES[-1]}"
        jq --raw-output '.content' "$GPT_HISTORY" >&2
        ;;
      *)
        GPT_HISTORY="$TMPDIR/$2"
        if ! [[ -f GPT_HISTORY ]]; then
          set -x
          exit 1
        fi
        ;;
      esac
    fi
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

DATE_FMT='+%Y-%m-%d %H:%M:%S'
GPT_HISTORY="${GPT_HISTORY:-"$TMPDIR/$(date -- "$DATE_FMT").json"}"
GPT_TMP="${GPT_TMP:-"$(mktemp)"}"
GPT_LVL="${GPT_LVL:-0}"
export -- GPT_HISTORY GPT_LVL GPT_STREAMING GPT_TMP MDPAGER
mkdir -v -p -- "$TMPDIR" >&2
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
  '{ stream: true, model: $model, messages: [.[] | select(.__gpt__ != true)] }'
  "$GPT_HISTORY"
)
JQ_RECV=(
  "${JQ_SC[@]}"
  --raw-input
  '{ __gpt__: true, content: . }'
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
  hr.sh '!' >&2
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
  if [[ -z "$USR" ]]; then
    REEXEC=1
  fi

  read -r -- LINE <<<"$USR"
  PRINT=1
  case "$LINE" in
  '>exit')
    exit 0
    ;;
  '>cls' | '>clear')
    REEXEC=1
    clear
    ;;
  '>die')
    GPT_HISTORY="$TMPDIR/$(date -- "$DATE_FMT").json"
    REEXEC=1
    ;;
  '>undo')
    for _ in {1..2}; do
      sed -E -e '$d' -i -- "$GPT_HISTORY"
    done
    REEXEC=1
    ;;
  '>buf')
    GPT_STREAMING=0
    REEXEC=1
    ;;
  '>unbuf')
    GPT_STREAMING=1
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

"${JQ_SEND[@]}" | completion.sh "${GPT_STREAMING:-0}" "$RX"
"${JQ_RECV[@]}" <"$RX" >>"$GPT_HISTORY"

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
