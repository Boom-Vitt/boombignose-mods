# Exit codes

All Orca scripts use the same meanings, so agents and CI can branch on them.

| Code | Meaning |
|---|---|
| 0 | OK / passed / dry-run plan is ready |
| 1 | Check failed (gate failed or timed out, invalid config or plan, doctor FAIL, `--strict` report issue) |
| 2 | Usage error, not a git repo, or nothing to check (`orca-gate.sh`: no checks found) |
| 3 | Refused by policy (no APPROVE, dirty tree, plan not accepted or changed, plan order, budget, duplicate) |
| 4 | Conflict during rebase/merge: hand to `codex`, then `/orca-review` again |
| 5 | Stale review: changes differ from what was approved, so re-review |
| 124 | Internal: a step hit its time limit (reported by the gate as a failed step, exit 1) |

| Script | Codes | Notes |
|---|---|---|
| `orca-gate.sh` | 0, 1, 2 | Per-step limit `ORCA_GATE_TIMEOUT` (default `reviewGate.stepTimeoutSec` = 1800 s); a timeout fails the step |
| `orca-merge.sh` | 0, 1, 2, 3, 4, 5 | Dry-run returns 3 when it would refuse |
| `orca-review-record.sh` | 0, 1, 2 | 1 = uncommitted changes |
| `orca-status.sh` | 0, 2 | Read-only |
| `orca-cleanup.sh` | 0, 2 | Dry-run by default; skips dirty worktrees rather than failing |
| `orca-doctor.sh` | 0, 1 | `claude mcp list` bounded by `ORCA_DOCTOR_MCP_TIMEOUT` (60 s) |
| `orca-ledger.sh` | 0, 2 | |
| `worktree-new.sh` | 0, 2, 3 | 3 = exists or `maxParallelWorktrees` reached |
| `orca-plan.mjs` | 0, 1, 2, 3 | `deps-merged` returns 3 when a dependency is not merged |
| `orca-queue.mjs` | 0, 2 | Read-only; predicts conflicts with `git merge-tree` |
| `orca-report.mjs` | 0, 1, 2 | 1 only with `--strict` |
| `orca-config-check.mjs` | 0, 1 | |

Network calls in scripts: `git fetch origin` (merge, worktree-new; failures tolerated), `git push` and `gh pr create` only for `orca-merge.sh --apply --pr`, `claude mcp list` in the doctor. `GIT_TERMINAL_PROMPT=0` is set so git never waits for credentials.
