#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CLAUDE_CONFIG_DIR="$1/.claude"
SELF="${0%/*}"

cp -af -- "$SELF/../opt/claude-code"/{agents,bin,hooks,libexec,rules,skills,AGENTS.md,keybindings.json} "$CLAUDE_CONFIG_DIR/"
mv -- "$CLAUDE_CONFIG_DIR/AGENTS.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
rm -fr -- "$CLAUDE_CONFIG_DIR/skills/shitpost"
