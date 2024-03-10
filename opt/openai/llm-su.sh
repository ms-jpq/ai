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

if ! ((RANDOM % 16)); then
  for F in "$TMPDIR"/*.json; do
    if ! [[ -s "$F" ]]; then
      printf -- '%s\0' "$F"
    fi
  done | xargs -0 -r -- rm -v -f --
fi

while (($#)); do
  case "$1" in
  -g | --gay)
    MDPAGER="$BASE/.venv/bin/gay"
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

GPT_HISTORY="${GPT_HISTORY:-"$TMPDIR/$(date -- '+%Y-%m-%d %H:%M:%S').json"}"
GPT_LVL="${GPT_LVL:-0}"
export -- GPT_HISTORY GPT_LVL GPT_STREAMING MDPAGER
mkdir -v -p -- "$TMPDIR" >&2
touch -- "$GPT_HISTORY"

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
  hr.sh '!' >&2
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
    REEXEC=1
    rm -v -fr -- "$GPT_HISTORY"
    ;;
  '>undo')
    REEXEC=1
    sed -E -e '1!d' -i -- "$GPT_HISTORY"
    ;;
  '>redo')
    sed -E -e '$d' -i -- "$GPT_HISTORY"
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

if [[ -t 0 ]]; then
  ((++GPT_LVL))
  exec -- "$0" "${ARGV[@]}"
fi
