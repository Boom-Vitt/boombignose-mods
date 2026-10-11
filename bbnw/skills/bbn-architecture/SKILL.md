---
name: bbn-architecture
description: Reference for the BBN v0.7 architecture - autopilot hub, herdr agent team, bbn-run.mjs harness, model tiers, Claude Code, Codex CLI, Hermes, Reviewer, plan checkpoint, merge queue, run ledger, worktree isolation, review gate, final verify, MCP routing, budgets.
---

# BBN architecture (v0.7)

Full document: `docs/bbn-architecture.md` in this plugin.

- **BBN**: hub (`bbn-workflow` skill or `bbn-orchestrator`, Claude Opus, in a herdr pane): requirements, research (Perplexity, WebSearch fallback), plan, dispatch, budgets
- **Team (herdr only)**: every role is a live teammate in its own tab of the hub's herdr workspace, driven by `bbn-team.sh` (`ask`/`wait`/`stop`, records each run in the ledger); no subagents. Builders keep their tab for `fix`, reviewers are fresh; exit 4 = waits on the user. Outside herdr the hub hands off with `bbn-bg.sh`
- **Harness**: `bbn-run.mjs` returns the next actions; with `--apply` it creates worktrees, runs acceptance checks and the gate, merges streams into a per-run integration branch in plan order, then needs a final review of the whole diff before one merge into the local base; cleans up and verifies; never pushes
- **Claude Code**: implement/refactor in one worktree (Claude Code teammate on Sonnet, Context7)
- **Codex**: the real Codex CLI as a teammate (`gpt-6.1-sol`, `xhigh`, `--approve-for-me`); multi-file integration, conflict owner; falls back to Claude Code when the CLI is missing (`bbn-team.sh` exit 3)
- **Hermes**: Hermes Agent teammate in its own profile `bbn` (BBN's own clean memory), one turn per ask; self-contained streams; falls back to Claude Code when the CLI or profile is missing
- **BBN Reviewer**: Claude Code teammate (Opus), fresh per verdict; approves the plan, reviews each branch with a Codex second opinion (`bbn-codex.sh review`), verdict bound to the patch fingerprint
- **Checkpoints**: `automation.planApproval` (`reviewer`/`user`), `automation.merge` (`local`/`ask`); stops after 3 failed checks or reviews, or no progress
- **Worktrees**: isolated port/env/DB; `/bbn-status` flags overlapping files
- **Guardrails**: secret scan, stream path ownership, plan checks for gitignored/untracked owned paths, `--no-rebase` for the final merge (ADR-0004)
- **Plan**: `.bbn/plan.json` validated and accepted before fan-out (ADR-0003)
- **Queue**: merge order from plan deps + `git merge-tree` conflict prediction
- **Ledger/report**: `<common-git-dir>/bbn/runs.jsonl`, turns per agent vs `maxTurns`
- **Scripts**: run (harness), team, bg, codex, plan, queue, gate (step timeout), merge (dry-run default, no force-push, optional draft PR), status, cleanup, doctor, ledger, report; shared exit codes in `docs/exit-codes.md`
