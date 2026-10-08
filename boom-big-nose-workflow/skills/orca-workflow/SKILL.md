---
name: orca-workflow
description: Use when the user mentions Orca, Boom Big Nose Workflow, coordinating Grok Build / Claude Code / Codex agents, parallel worktrees, a plan checkpoint, review gate, merge order, or merging agent branches.
---

# Orca workflow (v0.4)

1. `orca-orchestrator` is the hub. Start with `/orca-doctor` if setup is unknown (every problem has a `fix:` hint).
2. **Plan checkpoint** with `/orca-plan`: `grok-build` writes `.orca/plan.json` (streams, owned paths, dependsOn, acceptance), `check`, show the user, `accept` only after an explicit OK, then `apply --apply` creates the worktrees in dependency order.
3. Single ad-hoc stream without a plan: `/orca-worktree <slug>` (port, `.env.worktree`, `.orca/ownership.json`).
4. Implement with `claude-code`; integrate and resolve conflicts with `codex`. Budgets in `orca.config.json`; `maxTurns` is enforced per agent. Record each run: `orca-ledger.sh agent <role> --turns N --status ok|partial|failed`.
5. `/orca-queue` for merge order and predicted conflicts; `/orca-status` for a quick overview.
6. `/orca-review` -> `orca-gate.sh` + `orca-reviewer` verdict recorded.
7. `/orca-merge` (dry-run) -> `--apply` (local merge; refuses while a plan dependency is unmerged) or `--apply --pr` (draft PR). Never force-push.
8. `/orca-cleanup` removes merged worktrees; `/orca-report` shows turns vs budget.

Exit codes (all scripts): 0 ok, 1 check failed, 2 usage, 3 refused by policy, 4 conflict -> codex, 5 stale review. Quickstart: `docs/QUICKSTART.en.md` / `docs/QUICKSTART.md` (Thai).

## MCP routing and fallback
| Need | First choice | Fallback |
|---|---|---|
| Research, news, comparisons (Orca, grok-build) | Perplexity MCP | WebSearch + WebFetch |
| Library/API docs (claude-code, codex, reviewer) | Context7 MCP | WebFetch official docs |

Both MCPs are optional. If one is missing or unauthenticated, use the fallback and say so. Never ask for or print API keys.

Details: `docs/orca-architecture.md`.
