#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

PROMPT="$*"
if [[ -z $PROMPT ]]; then
  PROMPT="$(readline.sh green "${0##*/}")"
fi

MODEL="$(< "${0%/*}/../../etc/openai/image-model.txt")"

JSON="$(jq --exit-status --raw-input --arg model "$MODEL" '{ prompt: ., model: $model }' <<< "$PROMPT")"
RESP="$(curl.sh --json @- -- 'https://api.openai.com/v1/images/generations' <<< "$JSON")"

if jq --exit-status '.error' <<< "$RESP" > /dev/null; then
  jq <<< "$RESP" >&2
else
  US="$(jq --exit-status --raw-output '.data[].url' <<< "$RESP")"
  readarray -t -- URIS <<< "$US"

  for URI in "${URIS[@]}"; do
    printf -- '%s\n' "$URI"
    curl -- "$URI" | "$HOME/.config/zsh/bin/icat"
  done
fi
