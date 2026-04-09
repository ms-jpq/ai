#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# https://code.claude.com/docs/en/statusline

######################################
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'

_CYAN=$'\033[36m'
GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
######################################

######################################
JSON="$(tee)"
API_MS="$(jq -e --raw-output '.cost.total_api_duration_ms' <<< "$JSON")"
COST="$(jq -e --raw-output '.cost.total_cost_usd // 0' <<< "$JSON")"
LINES_ADDED="$(jq -e --raw-output '.cost.total_lines_added // 0' <<< "$JSON")"
LINES_REMOVED="$(jq -e --raw-output '.cost.total_lines_removed // 0' <<< "$JSON")"
MODEL="$(jq -e --raw-output '.model.display_name // "unknown"' <<< "$JSON")"
CTX_USED="$(jq -e --raw-output '.context_window.current_usage.input_tokens // 0' <<< "$JSON" | numfmt --to si)"
CTX_SIZE="$(jq -e --raw-output '.context_window.context_window_size // 0' <<< "$JSON" | numfmt --to si)"
CTX_PCT="$(jq -e --raw-output '.context_window.used_percentage // 0' <<< "$JSON" | cut -d. -f1)"
WD_CURR="$(jq -e --raw-output '.workspace.current_dir' <<< "$JSON")"
WD_PROJ="$(jq -e --raw-output '.workspace.project_dir' <<< "$JSON")"
######################################

######################################
printf -v COST_FMT -- '%.2f' "$COST"
COST_INFO="${BOLD}\$${COST_FMT}${RESET}"
######################################

######################################
SPENT_SECS=$((API_MS / 1000))
TIMEFMT='%M:%S'
if ((SPENT_SECS >= 3600)); then
  TIMEFMT="%H:$TIMEFMT"
fi
SPENT_TIME="$(date --utc --date="@$SPENT_SECS" -- "+$TIMEFMT")"

BAR_LEN=10
FILLED=$((CTX_PCT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))
BAR=''
for ((i = 0; i < FILLED; i++)); do BAR+='█'; done
for ((i = 0; i < EMPTY; i++)); do BAR+='░'; done

if ((CTX_PCT >= 90)); then
  BAR_COLOUR="$RED"
elif ((CTX_PCT >= 70)); then
  BAR_COLOUR="$YELLOW"
else
  BAR_COLOUR="$GREEN"
fi

MODEL_INFO="${MODEL}"

CTX_INFO="${DIM}${CTX_USED}/${CTX_SIZE}${RESET}"
USAGE_INFO="${DIM}⧗ ${SPENT_TIME}${RESET} ${BAR_COLOUR}${BAR}${RESET} ${CTX_INFO}"
######################################

######################################
LINES_DELTA=""
if ((LINES_ADDED > 0 || LINES_REMOVED > 0)); then
  LINES_DELTA=" ${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"
fi
######################################

######################################
DIR_INFO=''
if [[ $WD_CURR != "$WD_PROJ" ]]; then
  REL="$(realpath --no-symlinks --relative-to "$WD_PROJ" -- "$WD_CURR")"
  DIR_INFO=" $(basename -- "$WD_PROJ"):$REL"
fi
######################################

printf -- '%s' "${COST_INFO} ${MODEL_INFO} ${BOLD}-${RESET} ${USAGE_INFO}${LINES_DELTA} §  ${DIR_INFO}"
