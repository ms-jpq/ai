#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OUT="$1"
CLAUDE_CONFIG_DIR="$OUT/.claude"
SELF="${0%/*}"

mkdir -v -p -- "$CLAUDE_CONFIG_DIR"
cp -af --dereference -- "$SELF/../opt/claude-code"/{bin,hooks,keybindings.json} "$CLAUDE_CONFIG_DIR/"
mkdir -v -p -- "$CLAUDE_CONFIG_DIR/libexec"
cp -af -- "$SELF/../opt/claude-code/libexec"/{notify.sh,otel-headers-helper.sh} "$CLAUDE_CONFIG_DIR/libexec/"
cp -af --dereference -- "$SELF/../opt/claude-code/libexec"/{fmt-lint.sh,log-hooks.sh,read-session.sh,session-file.sh,which-session.sh} "$CLAUDE_CONFIG_DIR/libexec/"
cp -af -- "$SELF/../opt/codex/libexec/worktree" "$CLAUDE_CONFIG_DIR/libexec/"
cp -af --dereference -- "$SELF/../opt/opencode"/{agents,rules,skills,AGENTS.md} "$CLAUDE_CONFIG_DIR/"
if [[ -f $CLAUDE_CONFIG_DIR/AGENTS.md ]]; then
  mv -- "$CLAUDE_CONFIG_DIR/AGENTS.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
fi

rm -fr -- "$CLAUDE_CONFIG_DIR/skills/shitpost" "$CLAUDE_CONFIG_DIR/agents/web-research.md"

LAYERS=(
  agents.d
  hooks.d
  rules.d
  skills.d
)

for LAYER in "${LAYERS[@]}"; do
  SRC=$OUT/$LAYER
  if [[ -d $SRC ]]; then
    rsync --archive --copy-links --keep-dirlinks -- "$SRC" "$CLAUDE_CONFIG_DIR/"
  fi
done
