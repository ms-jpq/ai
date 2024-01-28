#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='m:,r:,h:'
LONG_OPTS='model:,role:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

ARGV=("$@")

TMP="${TMP:-"$(mktemp)"}"
GPT_HISTORY="${GPT_HISTORY:-"$(mktemp)"}"
GPT_ROLE="${GPT_ROLE:-""}"
export -- GPT_HISTORY TMP GPT_ROLE

BASE="${0%/*}/.."
LIBEXEC="$BASE/libexec"
MODEL="$(<"$BASE/etc/llm/model")"

while (($#)); do
  case "$1" in
  -m | --model)
    MODEL="$2"
    shift -- 2
    ;;
  -r | --role)
    GPT_ROLE="${GPT_ROLE:-"$2"}"
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

hr() {
  "$LIBEXEC/hr.sh" "$@" >&2
}

# shellcheck disable=SC2016
JQ1=(
  jq
  --exit-status
  --raw-input
  --slurp
  '{ role: $role, content: . }'
  --arg role
)
# shellcheck disable=SC2016
JQ2=(
  jq
  --exit-status
  --slurp
  --arg model "$MODEL"
  '{ model: $model, messages: . }'
)

INPUT="$("$LIBEXEC/readline.sh" "$0")"
printf -- '\n' >&2
read -r -- LINE <<<"$INPUT"
PRAGMA="$(tr -d ' ' <<<"$LINE")"
DIRECTIVE=1
REEXEC=0
case "$PRAGMA" in
'>cls')
  clear
  REEXEC=1
  ;;
'>die')
  GPT_HISTORY="$(mktemp)"
  REEXEC=1
  ;;
'>user' | '>system')
  GPT_ROLE="${PRAGMA#>}"
  INPUT="$(sed -E '1d' <<<"$INPUT")"
  ;;
*) DIRECTIVE=0 ;;
esac

if ((DIRECTIVE)); then
  hr !
  printf -- '%s\n' "$LINE" >&2
  hr !
  if ((REEXEC)); then
    exec -- "$0" "${ARGV[@]}"
  fi
fi

"${JQ1[@]}" "${GPT_ROLE:-"user"}" <<<"$INPUT" >>"$GPT_HISTORY"
QUERY="$("${JQ2[@]}" <"$GPT_HISTORY")"

hr
printf -v JQHIST -- '%q ' jq '.' "$GPT_HISTORY"
printf -- '%s\n%s\n' "$JQHIST" "> $GPT_ROLE:" >&2

"$LIBEXEC/llm/completion.sh" "$TMP" <<<"$QUERY"

exec -- "$0" "${ARGV[@]}"
