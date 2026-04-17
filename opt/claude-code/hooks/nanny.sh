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
  REASON='try again, and consider not executing commands via these mechanisms that are hard to write permissions for'
  ;;
'gosu '* | 'su '* | 'sudo '* | 'systemd-run '* | 'run0 '*)
  DECISION=deny
  REASON='do not elevate privileges'
  ;;
'brew '* | 'apt '* | 'apt-get '* | 'winget '*)
  DECISION=deny
  REASON='do not install system packages'
  ;;
'npx '* | 'bunx '* | 'pnpm dlx '* | 'yarn dlx '* | 'uvx '* | 'uv run '* | 'uv tool run '* | 'pipx run '*)
  DECISION=deny
  REASON='do not invoke tools through package-manager runners; install the tool locally and call it directly'
  ;;
'nohup '* | 'crontab '* | 'tmux '* | 'screen '* | 'zellij '*)
  DECISION=deny
  REASON='do not create persistent processes'
  ;;
'gpg-agent '* | 'ssh-agent '*)
  DECISION=deny
  REASON='do not spawn auth agents'
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
'gh '*' delete'* | 'gh '*' archive'*)
  DECISION=deny
  REASON='do not delete or archive GitHub resources'
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
'git '*' --delete'* | 'git '*' -D'* | 'git '*' --force'* | 'git '*' -f'* | 'git '*' -F'* | 'git '*' --hard'*)
  REASON='review destructive git operation'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
