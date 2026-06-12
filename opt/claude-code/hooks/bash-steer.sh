#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": ("⚠️ " + $reason)
  }
}
JQ

DECISION=ask
case "$CMD_LINE" in
'command -v '*)
  exit
  ;;
'command '* | 'eval '* | 'exec '*)
  DECISION=deny
  REASON='invoke the command directly, shell indirection is unnecessary'
  ;;
'gosu '* | 'su '* | 'sudo '* | 'systemd-run '* | 'run0 '*)
  DECISION=deny
  REASON='ask the user to escalate as needed'
  ;;
'brew '* | 'apt '* | 'apt-get '* | 'winget '*)
  DECISION=deny
  REASON='install locally, or ask the user to install system packages'
  ;;
'npx '* | 'bunx '* | 'pnpm dlx '* | 'yarn dlx '* | 'uvx '* | 'pipx run '*)
  DECISION=deny
  REASON='use locally installed tools, install as required'
  ;;
'nohup '* | 'crontab '* | 'tmux '* | 'screen '* | 'zellij '*)
  DECISION=deny
  REASON='use run_in_background for long-running work instead'
  ;;
'gpg-agent '* | 'ssh-agent '*)
  DECISION=deny
  REASON='rely on the users already-running auth agent'
  ;;
'systemctl '* | 'launchctl '*)
  REASON='review dangerous services command'
  ;;
'ssh '* | 'scp '* | 'rsync '*)
  REASON='review dangerous remote command'
  ;;
'gh '*' delete'* | 'gh '*' archive'*)
  REASON='review dangerous gh command'
  ;;
# *terraform*)
#   REASON='review dangerous terraform command'
#   ;;
'terraform '*)
  REASON='review dangerous terraform command'
  ;;
'kill '* | 'killall '* | 'pkill '*)
  REASON='review process killing'
  ;;
'git rebase '* | 'git commit '*--amend*)
  REASON='review history rewriting'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
