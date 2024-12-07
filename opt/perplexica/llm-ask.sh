#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='t:,f:'
LONG_OPTS='tee:,file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

BASE="${0%/*}"
SELF="${BASE##*/}"

export -- CHAT_HISTORY

CHAT_TEE=
while (($#)); do
  case "$1" in
  -t | --tee)
    CHAT_TEE="$2"
    mkdir -v -p -- "$CHAT_TEE" >&2
    shift -- 2
    ;;
  -f | --file)
    CHAT_HISTORY="$(nljson-ledger.sh "$SELF" "$2")"
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

read -r -d '' -- JQ <<- 'JQ' || true
{
  focusMode: "webSearch",
  optimizationMode: "speed",
  query: .[0].content,
  history: (.[1:] | map(values))
}
JQ

CHAT_DIEHARD=1 exec -- llm-chat.sh "$SELF" completion.sh 0 "$CHAT_TEE" - "$JQ"
