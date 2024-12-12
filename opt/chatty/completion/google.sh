#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'google'
  --header "Authorization: Bearer $GCP_VERTEX_API_KEY"
  --no-buffer
  --json @-
  -- "https://$GCP_LOCATION-aiplatform.googleapis.com/v1/projects/$GCP_PROJECT_ID/locations/$GCP_LOCATION-aiplatform/publishers/google/models/$GCP_VERTEX_MODEL_ID:streamGenerateContent"
)

read -r -d '' -- JQ <<- 'JQ' || true
{
  contents: (if length > 1 then .[1:] else . end) | map({ parts: [{ text: .content }], role: .role }),
  safetySettings: [],
  systemInstruction: {
    parts: [{ text: (if length > 1 then .[0].content else "" end) }],
    role: "system"
  }
}
JQ

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  "$JQ"
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
