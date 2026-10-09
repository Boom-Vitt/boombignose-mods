---
name: bbn-architecture
description: Reference for the BBN v0.5 architecture - autopilot hub, bbn-run.mjs harness, model tiers, Claude Code, Codex CLI, Reviewer, plan checkpoint, merge queue, run ledger, worktree isolation, review gate, final verify, MCP routing, budgets.
---

# BBN architecture (v0.5)

Full document: `docs/bbn-architecture.md` in this plugin.

- **BBN**: hub (`bbn-workflow` skill or `bbn-orchestrator`, Claude Opus): requirements, research (Perplexity, WebSearch fallback), plan, dispatch, budgets
- **Harness**: `bbn-run.mjs` returns the next actions; with `--apply` it creates worktrees, runs acceptance checks and the gate, merges into the local base in plan order, cleans up and verifies the merged base; never pushes
- **Claude Code**: implement/refactor in one worktree (Claude Sonnet, Context7)
- **Codex**: Claude Haiku driving the Codex CLI via `bbn-codex.sh`; multi-file integration, conflict owner; falls back to Claude Code when the CLI is missing
- **BBN Reviewer**: approves the plan, reviews each branch with a Codex second opinion, verdict bound to the patch fingerprint
- **Checkpoints**: `automation.planApproval` (`reviewer`/`user`), `automation.merge` (`local`/`ask`); stops after 3 failed checks or reviews, or no progress
- **Worktrees**: isolated port/env/DB; `/bbn-status` flags overlapping files
- **Plan**: `.bbn/plan.json` validated and accepted before fan-out (ADR-0003)
- **Queue**: merge order from plan deps + `git merge-tree` conflict prediction
- **Ledger/report**: `<common-git-dir>/bbn/runs.jsonl`, turns per agent vs `maxTurns`
- **Scripts**: run (harness), codex, plan, queue, gate (step timeout), merge (dry-run default, no force-push, optional draft PR), status, cleanup, doctor, ledger, report; shared exit codes in `docs/exit-codes.md`
