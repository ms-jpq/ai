#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# https://code.claude.com/docs/en/statusline

######################################
OSC8=$'\033]8;;'
ST=$'\033'"\\"

RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
ITALIC=$'\033[3m'

CYAN=$'\033[36m'
GREEN=$'\033[32m'
MAGENTA=$'\033[35m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
######################################

######################################
JSON="$(tee)"
SESSION_ID="$(jq -e --raw-output '.session_id // ""' <<< "$JSON")"
######################################

# shellcheck disable=SC2154
case "$CC_MODE" in
agent)
  # "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"
  TASKS="$(jq -e --raw-output '.tasks[].label | gsub("\n"; " ")' <<< "$JSON")"
  readarray -t -- TS <<< "$TASKS"
  TASK_INFO=''
  for TASK in "${TS[@]}"; do
    TASK_INFO+="> $TASK "
  done

  printf -- '%s' "$TASK_INFO"
  ;;
main)
  API_MS="$(jq -e --raw-output '.cost.total_api_duration_ms // 0' <<< "$JSON")"
  COST="$(jq -e --raw-output '.cost.total_cost_usd // 0' <<< "$JSON")"
  LINES_ADDED="$(jq -e --raw-output '.cost.total_lines_added // 0' <<< "$JSON")"
  LINES_REMOVED="$(jq -e --raw-output '.cost.total_lines_removed // 0' <<< "$JSON")"
  CTX_INPUT="$(jq -e --raw-output '.context_window.total_input_tokens // 0' <<< "$JSON" | numfmt --to si)"
  CTX_OUTPUT="$(jq -e --raw-output '.context_window.total_output_tokens // 0' <<< "$JSON" | numfmt --to si)"
  CTX_SIZE="$(jq -e --raw-output '.context_window.context_window_size // 0' <<< "$JSON" | numfmt --to si)"
  CTX_PCT="$(jq -e --raw-output '.context_window.used_percentage // 0' <<< "$JSON" | cut -d. -f1)"
  WD_CURR="$(jq -e --raw-output '.workspace.current_dir | gsub("\n"; " ")' <<< "$JSON")"
  WD_PROJ="$(jq -e --raw-output '.workspace.project_dir | gsub("\n"; " ")' <<< "$JSON")"
  ######################################

  SEP="${BOLD}⏐${RESET}"

  ######################################
  TRACE_INFO=''
  if [[ -n ${LANGFUSE_TRACE_URL:-} ]] && [[ -n ${LANGFUSE_PROJECT:-} ]]; then
    LANGFUSE_REST="${LANGFUSE_TRACE_URL#*://}"
    LANGFUSE_HOST="${LANGFUSE_TRACE_URL%%://*}://${LANGFUSE_REST%%/*}"
    TRACE_URL="${LANGFUSE_HOST}/project/${LANGFUSE_PROJECT}/sessions/${SESSION_ID}"
    TRACE_INFO="${BOLD}${OSC8}${TRACE_URL}${ST}⌬tel${OSC8}${ST}${ST}${RESET} ${SEP} "
  fi
  ######################################

  ######################################
  TOT_COUNT="${BOLD}${MAGENTA}↑${RESET} ${CTX_INPUT} ${BOLD}${CYAN}↓${RESET} ${CTX_OUTPUT}"
  printf -v COST_FMT -- '%.2f' "$COST"
  COST_INFO="${BOLD}\$${COST_FMT}${RESET}"
  ######################################

  ######################################
  SPENT_SECS=$((API_MS / 1000))
  TIMEFMT='%M:%S'
  if ((SPENT_SECS >= 3600)); then
    TIMEFMT="%H:$TIMEFMT"
  fi
  TIME_INFO="${ITALIC}$(date --utc --date="@$SPENT_SECS" -- "+$TIMEFMT")${RESET}"
  ######################################

  ######################################
  BAR_LEN=10
  FILLED=$((CTX_PCT * BAR_LEN / 100))

  printf -v BAR -- '%*s' $((FILLED)) ''
  BAR="${BAR// /'█'}"
  printf -v _EMPTY -- '%*s' $((BAR_LEN - FILLED)) ''
  BAR+="${_EMPTY// /'░'}"

  if ((CTX_PCT >= 80)); then
    BAR_COLOUR="$RED"
  elif ((CTX_PCT >= 70)); then
    BAR_COLOUR="$YELLOW"
  else
    BAR_COLOUR="$GREEN"
  fi

  USAGE_INFO="${BAR_COLOUR}${BAR}${RESET} ${DIM}${CTX_SIZE}${RESET}"
  ######################################

  ######################################
  DIR_INFO=''
  if [[ $WD_CURR != "$WD_PROJ" ]]; then
    REL="$(realpath --no-symlinks --relative-to "$WD_PROJ" -- "$WD_CURR")"
    DIR_INFO=" ${BOLD}$(basename -- "$WD_PROJ"):$REL${RESET}"
  fi
  ######################################

  ######################################
  LINES_DELTA=''
  if ((LINES_ADDED > 0)); then
    LINES_DELTA+=" ${GREEN}+${LINES_ADDED}${RESET}"
  fi
  if ((LINES_REMOVED > 0)); then
    if ((LINES_ADDED > 0)); then
      LINES_DELTA+=","
    else
      LINES_DELTA+=" "
    fi
    LINES_DELTA+="${RED}-${LINES_REMOVED}${RESET}"
  fi
  ######################################

  printf -- '%s' "${TRACE_INFO}${COST_INFO} ${BOLD}⟢${RESET} ${TIME_INFO} ${BOLD}∷${RESET} ${TOT_COUNT} ${SEP} ${USAGE_INFO} ${SEP}${LINES_DELTA}${DIR_INFO}"
  ;;
*)
  set -v
  exit 1
  ;;
esac
