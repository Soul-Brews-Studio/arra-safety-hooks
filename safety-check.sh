#!/bin/bash
# Safety check hook - blocks dangerous commands
# Input: JSON via stdin with tool_input.command

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)

# === BETA RULES ===
# Toggle: touch /tmp/arra-safety-beta-on  → enable beta rules
#         rm /tmp/arra-safety-beta-on     → disable beta rules
BETA=false; [ -f /tmp/arra-safety-beta-on ] && BETA=true

if $BETA; then
  # Block raw tmux commands — use maw instead
  if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*tmux\s+(send-keys|list-windows|list-sessions|capture-pane|select-window|new-window)'; then
    echo "BLOCKED: Never use raw tmux send-keys." >&2
    echo "" >&2
    echo "Use maw-js instead:" >&2
    echo "  maw hey <window> \"message\"  — send message to agent" >&2
    echo "  maw peek <window>           — view agent output" >&2
    echo "  maw ls                      — list sessions" >&2
    echo "  maw spawn <name>            — create new agent" >&2
    echo "  maw a <window>              — attach to session" >&2
    echo "" >&2
    echo "Missing a maw command? Create an issue:" >&2
    echo "  gh issue create --repo Soul-Brews-Studio/maw-js --title 'feat: maw <command>'" >&2
    exit 2
  fi

  # Block bun src/cli.ts and bun src/server.ts — use maw binary
  # Allow: bun build, bun test, bun install, bun link (legitimate build commands)
  if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*bun\s+(run\s+)?src/(cli|server)\.ts'; then
    echo "BLOCKED: Never run maw via bun src/cli.ts." >&2
    echo "" >&2
    echo "Install maw globally first:" >&2
    echo "  cd ~/Code/github.com/Soul-Brews-Studio/maw-js && bun link" >&2
    echo "" >&2
    echo "Then use the maw binary:" >&2
    echo "  maw hey <window> \"message\"" >&2
    echo "  maw ls / maw peek / maw spawn" >&2
    echo "" >&2
    echo "Need a new feature? Create an issue:" >&2
    echo "  gh issue create --repo Soul-Brews-Studio/maw-js --title 'feat: ...'" >&2
    exit 2
  fi
  # Warn on localhost — prefer hostname (white.wg, mba.wg, etc.)
  HOSTNAME=$(hostname -s 2>/dev/null || echo "")
  if echo "$CMD" | grep -qE 'localhost|127\.0\.0\.1'; then
    echo "⚠ WARNING: Using localhost — consider using ${HOSTNAME}.wg instead." >&2
    echo "  localhost doesn't work cross-machine. Use WireGuard hostnames for fleet access." >&2
    # Warning only — don't block (exit 0 continues)
  fi
  # Warn on .local — suggest .wg fallback if unreachable
  if echo "$CMD" | grep -qE '[a-z]+\.local[:/]'; then
    HOST=$(echo "$CMD" | grep -oE '[a-z]+\.local' | head -1)
    WG_HOST="${HOST%.local}.wg"
    echo "⚠ NOTE: Using ${HOST} — if unreachable, try ${WG_HOST} (WireGuard)." >&2
    # Warning only — don't block
  fi
fi

# Block dangerous patterns - be specific to avoid false positives
# Only block commands at START of line/command (not in text body, heredoc, echo, etc.)
# Patterns: start of string, after ;, after &&, after ||, after newline

# Block rm -rf and rm -f when actual commands (not in text)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*rm\s+-r?f\s'; then
  echo "BLOCKED: rm -f / rm -rf not allowed. Always use mv to /tmp instead." >&2
  exit 2
fi

# Block git/npm force flags only when actual command
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*(git|npm|yarn|pnpm)\s+[a-z]+\s+.*(\s-f(\s|$)|--force(\s|$)|--force-with-lease(\s|$))'; then
  echo "BLOCKED: Force flags not allowed (including --force-with-lease). Use git pull --no-rebase + merge." >&2
  exit 2
fi
# Also catch -f immediately after subcommand (git push -f)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*(git|npm|yarn|pnpm)\s+[a-z]+\s+-f(\s|$)'; then
  echo "BLOCKED: Force flag -f not allowed. Nothing is Deleted." >&2
  exit 2
fi

# Block reset --hard
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard not allowed." >&2
  exit 2
fi

# Block direct push to main
if echo "$CMD" | grep -qE 'git\s+push\s+(origin\s+)?main(\s|$)'; then
  echo "BLOCKED: Never push directly to main. Use alpha branch + PR." >&2
  exit 2
fi

# Block git commit --amend (breaks multi-agent sync - causes hash divergence)
if echo "$CMD" | grep -qE 'git\s+commit\s+.*--amend'; then
  echo "BLOCKED: Never use --amend in multi-agent setup. Creates hash divergence." >&2
  echo "Use a NEW commit instead: git commit -m 'fix: ...' " >&2
  exit 2
fi

# Block git checkout -- (discards uncommitted changes)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+checkout\s+--\s'; then
  echo "BLOCKED: git checkout -- discards changes. Use git stash instead." >&2
  exit 2
fi

# Block git restore . (discards all uncommitted changes)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+restore\s+\.'; then
  echo "BLOCKED: git restore . discards all changes. Use git stash instead." >&2
  exit 2
fi

# Block git clean -f (deletes untracked files permanently)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+clean\s+.*-[a-zA-Z]*f'; then
  echo "BLOCKED: git clean -f deletes untracked files permanently. Move to /tmp instead." >&2
  exit 2
fi

# Block git branch -D (force delete branch — Nothing is Deleted)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+branch\s+-D\s'; then
  echo "BLOCKED: git branch -D force-deletes branch. Use -d (safe delete) instead." >&2
  exit 2
fi

# Block git stash drop/clear (loses stashed work)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+stash\s+(drop|clear)'; then
  echo "BLOCKED: git stash drop/clear loses work. Nothing is Deleted." >&2
  exit 2
fi

# Block --no-verify (skips pre-commit hooks — bypasses safety)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+(commit|push)\s+.*--no-verify'; then
  echo "BLOCKED: --no-verify skips safety hooks. Fix the hook issue instead." >&2
  exit 2
fi

# Block gh pr merge (DISABLED - local project hook handles this for worktree agents)
# Main agent CAN merge after explicit user approval
# if echo "$CMD" | grep -qE 'gh\s+pr\s+merge'; then
#   echo "BLOCKED: Never merge PRs. Wait for user approval." >&2
#   exit 2
# fi

# Block gh pr create to upstream repos that are not ours
# Uses cached org list (refreshed daily) + personal account
ORGS_CACHE="/tmp/gh-my-orgs.txt"
if [ ! -f "$ORGS_CACHE" ] || [ $(( $(date +%s) - $(stat -c %Y "$ORGS_CACHE" 2>/dev/null || echo 0) )) -gt 86400 ]; then
  HTTPS_PROXY="" GIT_SSL_NO_VERIFY=1 gh api user/orgs --jq '.[].login' > "$ORGS_CACHE" 2>/dev/null || true
  echo "nazt" >> "$ORGS_CACHE"  # personal account
fi
if echo "$CMD" | grep -qE 'gh\s+pr\s+create'; then
  REPO=$(echo "$CMD" | grep -oP '(?<=--repo\s)[^\s]+' || true)
  if [ -n "$REPO" ]; then
    ORG=$(echo "$REPO" | cut -d/ -f1)
    if ! grep -qix "$ORG" "$ORGS_CACHE" 2>/dev/null; then
      echo "BLOCKED: Cannot create PR to upstream repo '$REPO'. Not your org/account." >&2
      exit 2
    fi
  fi
fi

exit 0
