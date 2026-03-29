#!/bin/bash
# Install ARRA safety hooks for Claude Code
set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing ARRA safety hooks..."

# 1. Copy hook script
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/safety-check.sh" "$HOOKS_DIR/safety-check.sh"
chmod +x "$HOOKS_DIR/safety-check.sh"
echo "  Copied safety-check.sh to $HOOKS_DIR/"

# 2. Patch settings.json
HOOK_ENTRY='{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "'"$HOOKS_DIR"'/safety-check.sh",
      "timeout": 5
    }
  ]
}'

if [ ! -f "$SETTINGS" ]; then
  # Create fresh settings with hooks
  echo '{}' | jq --argjson hook "$HOOK_ENTRY" '.hooks.PreToolUse = [$hook]' > "$SETTINGS"
  echo "  Created $SETTINGS with safety hook"
elif jq -e '.hooks.PreToolUse' "$SETTINGS" > /dev/null 2>&1; then
  # Check if safety-check.sh already registered
  if jq -e '.hooks.PreToolUse[] | select(.hooks[]?.command | test("safety-check"))' "$SETTINGS" > /dev/null 2>&1; then
    echo "  safety-check.sh already in settings.json — skipped"
  else
    # Append to existing PreToolUse array
    jq --argjson hook "$HOOK_ENTRY" '.hooks.PreToolUse = [$hook] + .hooks.PreToolUse' "$SETTINGS" > "$SETTINGS.tmp"
    mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  Added safety hook to existing PreToolUse config"
  fi
else
  # Add hooks.PreToolUse section
  jq --argjson hook "$HOOK_ENTRY" '.hooks.PreToolUse = [$hook]' "$SETTINGS" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
  echo "  Added PreToolUse hooks section to settings.json"
fi

echo ""
echo "Done. Safety hook blocks (12 rules):"
echo "  - rm -rf / rm -f"
echo "  - git --force / -f / --force-with-lease"
echo "  - git reset --hard"
echo "  - git commit --amend"
echo "  - git push main"
echo "  - git checkout -- / git restore ."
echo "  - git clean -f"
echo "  - git branch -D"
echo "  - git stash drop / clear"
echo "  - --no-verify"
echo "  - gh pr create to non-owned orgs"
echo ""
echo "Beta rules (opt-in): touch /tmp/arra-safety-beta-on"
echo "  - tmux send-keys → use maw hey"
echo "  - bun run src/cli.ts → use maw install"
