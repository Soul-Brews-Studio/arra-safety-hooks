#!/bin/bash
# Safety check hook - blocks dangerous commands
# Input: JSON via stdin with tool_input.command

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)

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
