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
| `git checkout -- .` | Use `git stash` instead |
| `git restore .` | Use `git stash` instead |
| `git clean -f` | Deletes untracked files permanently |
| `git branch -D` | Use `-d` (safe delete) instead |
| `git stash drop` / `clear` | Nothing is Deleted |
| `--no-verify` on commit/push | Fix the hook, don't skip it |
| `gh pr create` to foreign orgs | Ownership check |

### Beta rules (opt-in)

| Pattern | Why | Toggle |
|---------|-----|--------|
| `tmux send-keys` | Use `maw hey` instead | `touch /tmp/arra-safety-beta-on` |
| `bun run src/cli.ts` | Use installed `maw` binary | `rm /tmp/arra-safety-beta-on` to disable |

```bash
# Enable beta rules
touch /tmp/arra-safety-beta-on

# Disable beta rules
rm /tmp/arra-safety-beta-on
```

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

### Timeline

| Date | Event |
|------|-------|
| **Dec 27, 2025** | Nat Weerawan + Claude Opus 4.5 discover that CLAUDE.md rules rely on AI compliance alone. Decide: **enforcement > documentation**. Learn the hook protocol (stdin JSON, exit 2 = block). |
| **Dec 28, 2025** | First `safety-check.sh` born in `Nat-s-Agents` repo — commit `4dbc2bb`. Includes worktree boundary enforcement for parallel AI agents. Same day: bug fixes for false positives (`[ -f ]` shell tests, "force" in commit messages). |
| **Jan 16, 2026** | Bundled into Oracle Starter Kit. Every new Oracle born after this inherits safety hooks. |
| **Mar 22, 2026** | Extracted to `oracle-skills-cli` as shared template for the Oracle family. |
| **Mar 29, 2026** | This repo created by Neo (Claude Opus 4.6) — single source of truth for safety hooks. |

### The Insight

The original Oracle multi-agent system had 5 AI agents working in parallel worktrees. CLAUDE.md told them "never force push" — but an agent under pressure could still do it. The solution: a PreToolUse hook that makes dangerous commands **impossible**, not just discouraged.

```
Documentation = suggestion (AI can ignore)
Hook with exit 2 = wall (AI cannot bypass)
```

### Evolution

The first version enforced **worktree boundaries** — agents in `agents/N` couldn't `cd` outside their sandbox. It evolved into a **universal safety net**:

- v1 (Dec 2025): Worktree boundaries + basic blocks. Hardcoded macOS paths.
- v2 (Jan 2026): Portable. Part of Oracle Starter Kit.
- v3 (Mar 2026): Smart regex anchoring. Org membership check. No worktree coupling.

### Fun fact

During this repo's creation, the hook blocked its own commit message — the word "amend" in the description triggered the `git commit --amend` rule. Proof it works.

## Part of ARRA Oracle

191+ AI agents (Oracles) share the same 5 Principles. Each has a different purpose. This hook enforces Principle 1: **Nothing is Deleted**.

- [ARRA Oracle](https://github.com/Soul-Brews-Studio/arra-oracle) — the ecosystem
- [Oracle Skills CLI](https://github.com/Soul-Brews-Studio/oracle-skills-cli) — shared instruments

---

Created by [Neo](https://github.com/laris-co/neo-oracle) (Claude Opus 4.6) for Nat Weerawan ([@nazt](https://github.com/nazt))

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>

## License

MIT
