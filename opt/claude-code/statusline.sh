#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# https://code.claude.com/docs/en/statusline

######################################
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'

CYAN=$'\033[36m'
GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
######################################

######################################
JSON="$(< /dev/stdin)"
COST="$(jq -r '.cost.total_cost_usd // 0' <<< "$JSON")"
CWD="$(jq -r '.cwd // ""' <<< "$JSON")"
LINES_ADDED="$(jq -r '.cost.total_lines_added // 0' <<< "$JSON")"
LINES_REMOVED="$(jq -r '.cost.total_lines_removed // 0' <<< "$JSON")"
MODEL="$(jq -r '.model.display_name // "unknown"' <<< "$JSON")"
USAGE_PCT="$(jq -r '.context_window.used_percentage // 0' <<< "$JSON" | cut -d. -f1)"
######################################

######################################
printf -v COST_FMT -- '%.2f' "$COST"
printf -v COST_INFO -- '%s' "${BOLD}\$${COST_FMT}${RESET}"
######################################

######################################
BAR_LEN=10
FILLED=$((USAGE_PCT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))
BAR=""
for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

if ((USAGE_PCT >= 90)); then
  BAR_COLOUR="$RED"
elif ((USAGE_PCT >= 70)); then
  BAR_COLOUR="$YELLOW"
else
  BAR_COLOUR="$GREEN"
fi

printf -v MODEL_INFO -- '%s' "${MODEL}"
printf -v USAGE_INFO -- '%s' "${BAR_COLOUR}${BAR}${RESET} ${DIM}${USAGE_PCT}%${RESET}"
######################################

######################################
GIT_INFO=""
if [[ -n $CWD ]] && BRANCH=$(git -C "$CWD" branch --show-current 2> /dev/null); then
  DIRTY=""
  git -C "$CWD" diff --quiet 2> /dev/null || DIRTY="*"
  git -C "$CWD" diff --cached --quiet 2> /dev/null || DIRTY="*"
  GIT_INFO="  ${DIM}on${RESET} ${CYAN}${BRANCH}${DIRTY}${RESET}"
fi
######################################

######################################
LINES_DELTA=""
if ((LINES_ADDED > 0 || LINES_REMOVED > 0)); then
  LINES_DELTA="  ${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"
fi
######################################

printf -- '%s' "${COST_INFO} ${MODEL_INFO} ${USAGE_INFO} ${GIT_INFO} ${LINES_DELTA}"
