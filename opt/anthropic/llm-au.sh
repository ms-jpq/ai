#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='s:,t:,f:'
LONG_OPTS='stream:,tee:,file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

SELF="${0##*/}"
BASE="${0%/*}/../.."
MODEL="$(< "$BASE/etc/anthropic/model")"
TOKENS="$(< "$BASE/etc/anthropic/max_tokens")"

export -- CHAT_TEE CHAT_HISTORY

CHAT_STREAMING=2
while (($#)); do
  case "$1" in
  -s | --stream)
    CHAT_STREAMING="$2"
    shift -- 2
    ;;
  -t | --tee)
    TEE="$2"
    mkdir -v -p -- "$TEE" >&2
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
{ stream: true, model: $model, max_tokens: $tokens, messages: .[1:], system: .[0].content }
JQ

exec -- llm-chat.sh "$SELF" completion.sh "$CHAT_STREAMING" --arg model "$MODEL" --argjson tokens "$TOKENS" "$JQ"
