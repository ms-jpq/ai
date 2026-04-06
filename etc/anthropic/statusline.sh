#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# https://code.claude.com/docs/en/statusline

input="$(cat)"

# ANSI colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'
BOLD='\033[1m'

# Parse fields
MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"')
PCT=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADDED=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')
CWD=$(printf '%s' "$input" | jq -r '.cwd // ""')

# Context bar (10 chars wide)
BAR_LEN=10
FILLED=$((PCT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))
BAR=""
for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

# Color the bar by threshold
if ((PCT >= 90)); then
  BAR_COLOR="$RED"
elif ((PCT >= 70)); then
  BAR_COLOR="$YELLOW"
else
  BAR_COLOR="$GREEN"
fi

# Git branch + dirty marker (uses cwd from JSON so it's always the right repo)
GIT_INFO=""
if [[ -n $CWD ]] && BRANCH=$(git -C "$CWD" branch --show-current 2> /dev/null); then
  DIRTY=""
  git -C "$CWD" diff --quiet 2> /dev/null || DIRTY="*"
  git -C "$CWD" diff --cached --quiet 2> /dev/null || DIRTY="*"
  GIT_INFO="  ${DIM}on${RESET} ${CYAN}${BRANCH}${DIRTY}${RESET}"
fi

# Cost
COST_FMT=$(printf '$%.4f' "$COST")

# Lines changed this session
DELTA=""
if ((LINES_ADDED > 0 || LINES_REMOVED > 0)); then
  DELTA="  ${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"
fi

echo -e "${BOLD}${MODEL}${RESET}${GIT_INFO}  ${BAR_COLOR}${BAR}${RESET} ${PCT}%  ${DIM}${COST_FMT}${RESET}${DELTA}"
