# arra-safety-hooks

Claude Code safety hooks — enforcement over documentation.

> "CLAUDE.md says 'never force push' but relies on AI compliance. A hook with `exit 2` makes it impossible."
> — Born December 27, 2025

## What it blocks

| Pattern | Why |
|---------|-----|
| `rm -rf` / `rm -f` | Use `mv` to `/tmp` instead |
| `git push --force` / `-f` / `--force-with-lease` | Nothing is Deleted |
| `git reset --hard` | Irreversible |
| `git commit --amend` | Breaks multi-agent hash sync |
| `git push origin main` | Always branch + PR |
| `gh pr create` to foreign orgs | Ownership check |

## Install

```bash
git clone https://github.com/Soul-Brews-Studio/arra-safety-hooks.git
cd arra-safety-hooks
bash install.sh
```

This copies `safety-check.sh` to `~/.claude/hooks/` and registers it as a `PreToolUse` hook in `~/.claude/settings.json`.

## How it works

Claude Code hooks receive JSON via **stdin** when a tool is about to execute:

```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "git push --force" }
}
```

The hook parses the command with `jq`, checks against blocked patterns, and:
- `exit 0` — allow
- `exit 2` — block (message shown via stderr)

Smart regex anchoring (`^|;|&&|\|\|`) ensures only actual commands are blocked, not text in docs or commit messages.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `jq` for JSON parsing
- `gh` CLI (optional, for org membership check)

## Origin

Created by Nat Weerawan + Claude Opus 4.5 on December 27-28, 2025 in the Oracle multi-agent system. Originally enforced worktree boundaries for parallel AI agents. Now used across 191+ Oracle instances.

Part of the [ARRA Oracle](https://github.com/Soul-Brews-Studio/arra-oracle) ecosystem.

## License

MIT
