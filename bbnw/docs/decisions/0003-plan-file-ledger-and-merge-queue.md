# ADR-0003: Plan file as the checkpoint, run ledger, predicted-conflict merge queue

- **Status:** Accepted
- **Date:** 2026-10-08
- **Deciders:** Boom + BBN workflow maintainers

## Context

Up to v0.3 the plan checkpoint, merge order and budgets lived only in the orchestrator's prompt. Nothing checked that a plan had been accepted before worktrees were created, two streams could own the same files without anyone noticing until a rebase conflict, merge order was a judgement call, and `maxTurns` was enforced but never reported, so nobody could see which role kept running out of turns.

## Decision

1. **The plan is a file.** `<main worktree>/.bbn/plan.json` (schema `bbn.plan.schema.json`, git-excluded) holds goal, streams (slug, role, owned paths, `dependsOn`, acceptance checks) and risks. `bbn-plan.mjs check` validates it: schema, stream cap, minimum acceptance checks, no absolute or `..` paths, known dependencies, no cycles, and **no two streams owning the same path unless one depends on the other**. `accept` stores a hash of goal/base/streams; `apply` refuses (exit 3) unless the plan is accepted and unchanged, then creates worktrees in dependency order with ownership maps.
2. **Merge order follows the plan and predicted conflicts.** `bbn-queue.mjs` predicts conflicts against the base and between branches with `git merge-tree --write-tree` (no checkout is touched) and orders branches by: dependencies, ready (gate + review current), base conflicts, pairwise conflicts, overlaps, diff size. `bbn-merge.sh --apply` refuses (exit 3) a branch whose plan dependencies are not merged yet; `--ignore-order` overrides.
3. **A ledger in the common git dir.** Scripts append one JSON line per event (gate, review, merge, worktree, plan, cleanup) to `<common-git-dir>/bbn/runs.jsonl`, shared by all worktrees and never committed. The orchestrator records every subagent run with `bbn-ledger.sh agent <role> --turns N --status ok|partial|failed`. `bbn-report.mjs` compares turns with `maxTurns`.

## Consequences

- The checkpoint is enforced by a script, not only by the prompt; re-planning means edit, check, accept again.
- Ownership conflicts are caught at plan time, and remaining file conflicts are predicted before any rebase.
- Turn counts are what the orchestrator records (Claude Code shows a tool-use count in each subagent result but does not expose an exact turn count to scripts). `maxTurns` is still enforced by Claude Code; the report is for tuning budgets, not enforcement.
- `BBN_LEDGER=0` disables the ledger. The ledger stays on the user's machine; nothing is uploaded.
- Requires git 2.38+ for `merge-tree --write-tree` (the doctor checks the git version).
