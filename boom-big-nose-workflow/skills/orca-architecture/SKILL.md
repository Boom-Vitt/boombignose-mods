---
name: orca-architecture
description: Reference for the Orca v0.4 architecture - hub, Grok Build, Claude Code, Codex, Reviewer, plan checkpoint, merge queue, run ledger, worktree isolation, review gate, MCP routing, budgets.
---

# Orca architecture (v0.4)

Full document: `docs/orca-architecture.md` in this plugin.

- **Orca**: hub, plan checkpoint, budgets, merge order
- **Grok Build**: plan + research (Perplexity, WebSearch fallback)
- **Claude Code**: implement/refactor in one worktree (Context7)
- **Codex**: multi-file integration, conflict owner
- **Orca Reviewer**: gate + recorded verdict bound to the patch fingerprint
- **Worktrees**: isolated port/env/DB; `/orca-status` flags overlapping files
- **Plan**: `.orca/plan.json` validated and accepted before fan-out (ADR-0003)
- **Queue**: merge order from plan deps + `git merge-tree` conflict prediction
- **Ledger/report**: `<common-git-dir>/orca/runs.jsonl`, turns per agent vs `maxTurns`
- **Scripts**: plan, queue, gate (step timeout), merge (dry-run default, no force-push, optional draft PR), status, cleanup, doctor, ledger, report; shared exit codes in `docs/exit-codes.md`
