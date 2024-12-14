#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OPTS='m:,s:,t:,f:'
LONG_OPTS='model:,stream:,tee:,file:'
GO="$(getopt --options="$OPTS" --longoptions="$LONG_OPTS" --name="$0" -- "$@")"
eval -- set -- "$GO"

BASE="${0%/*}"
SELF="${BASE##*/}"

export -- CHAT_HISTORY

CHAT_TEE=
CHAT_STREAMING=2
while (($#)); do
  case "$1" in
  -m | --model)
    MODEL="$2"
    shift -- 2
    ;;
  -s | --stream)
    CHAT_STREAMING="$2"
    shift -- 2
    ;;
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

if [[ -z ${MODEL:-""} ]]; then
  MODEL="$(fzf < "$BASE/../../etc/chatty/models.txt")"
fi

ARGV=()

case "$MODEL" in
gpt*)
  COMP='openai'
  read -r -d '' -- JQ <<- 'JQ' || true
{
  stream: true,
  model: $model,
  messages: .
}
JQ
  ;;
claude*)
  COMP='anthropic'
  read -r -d '' -- JQ <<- 'JQ' || true
{
  stream: true,
  model: $model,
  max_tokens: 4096,
  system: (if length > 1 then .[0].content else "" end),
  messages: (if length > 1 then .[1:] else . end)
}
JQ
  ;;
gemini*)
  COMP='google'
  export -- GEMINI_MODEL="$MODEL"
  read -r -d '' -- JQ <<- 'JQ' || true
{
  safetySettings: [
    { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
    { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
    { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
    { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
    { category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE" }
  ],
  contents: (if length > 1 then .[1:] else . end) | map({ role: (if .role == "assistant" then "model" else .role end), parts: [{ text: .content }] }),
  systemInstruction: {
    parts: [{ text: (if length > 1 then .[0].content else "" end) }],
    role: "system"
  }
}
JQ
  ;;
*)
  COMP='ollama'
  read -r -d '' -- JQ <<- 'JQ' || true
{
  model: $model,
  messages: .
}
JQ
  ;;
esac

ARGV+=(--arg model "$MODEL")

exec -- llm-chat.sh "$SELF" "$BASE/completion/$COMP.sh" "$CHAT_STREAMING" "$CHAT_TEE" "$*" "${ARGV[@]}" "$JQ"
