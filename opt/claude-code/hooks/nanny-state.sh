#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": "⚠️ " + $reason
  }
}
JQ

DECISION=ask
case "$CMD_LINE" in
'gosu '* | 'su '* | 'sudo '*)
  DECISION=deny
  REASON='do not elevate privileges'
  ;;
'brew '* | 'apt '* | 'apt-get '* | 'winget '*)
  DECISION=deny
  REASON='do not install system packages'
  ;;
'bash '* | 'dash '* | 'fish '* | 'sh '* | 'zsh '*)
  DECISION=deny
  REASON='consider not doing nested shell scripts'
  ;;
'kill '* | 'killall '* | 'pkill '*)
  DECISION=deny
  REASON='do not kill processes'
  ;;
'nohup '* | 'crontab '*)
  DECISION=deny
  REASON='do not create persistent processes'
  ;;
'systemctl '* | 'launchctl '*)
  DECISION=deny
  REASON='do not manage system services'
  ;;
'ssh '* | 'scp '* | 'rsync '*)
  DECISION=deny
  REASON='do not make remote connections'
  ;;
'git stash '*)
  DECISION=deny
  REASON='do not use git stash, it is hard to track'
  ;;
'python -c '* | 'python3 -c '* | 'ruby -e '* | 'node -e '*)
  REASON='review inline scripts'
  ;;
'git rebase '* | 'git commit '*--amend*)
  REASON='review history rewriting'
  ;;
'git '*--delete* | 'git '*-D* | 'git '*--force* | 'git '*-f* | 'git '*-F* | 'git '*--hard*)
  REASON='review destructive git operation'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
