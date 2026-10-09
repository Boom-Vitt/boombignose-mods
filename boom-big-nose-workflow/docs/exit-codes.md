# Exit codes

All BBN scripts use the same meanings, so agents and CI can branch on them.

| Code | Meaning |
|---|---|
| 0 | OK / passed / dry-run plan is ready |
| 1 | Check failed (gate failed or timed out, invalid config or plan, doctor FAIL, `--strict` report issue) |
| 2 | Usage error, not a git repo, or nothing to check (`bbn-gate.sh`: no checks found) |
| 3 | Refused by policy (no APPROVE, dirty tree, plan not accepted or changed, plan order, budget, duplicate) |
| 4 | Conflict during rebase/merge: hand to `codex`, then `/bbn-review` again |
| 5 | Stale review: changes differ from what was approved, so re-review |
| 124 | Internal: a step hit its time limit (reported by the gate as a failed step, exit 1) |

| Script | Codes | Notes |
|---|---|---|
| `bbn-gate.sh` | 0, 1, 2 | Per-step limit `BBN_GATE_TIMEOUT` (default `reviewGate.stepTimeoutSec` = 1800 s); a timeout fails the step |
| `bbn-merge.sh` | 0, 1, 2, 3, 4, 5 | Dry-run returns 3 when it would refuse |
| `bbn-review-record.sh` | 0, 1, 2 | 1 = uncommitted changes |
| `bbn-status.sh` | 0, 2 | Read-only |
| `bbn-cleanup.sh` | 0, 2 | Dry-run by default; skips dirty worktrees rather than failing |
| `bbn-doctor.sh` | 0, 1 | `claude mcp list` bounded by `BBN_DOCTOR_MCP_TIMEOUT` (60 s) |
| `bbn-ledger.sh` | 0, 2 | |
| `worktree-new.sh` | 0, 2, 3 | 3 = exists or `maxParallelWorktrees` reached |
| `bbn-plan.mjs` | 0, 1, 2, 3 | `deps-merged` returns 3 when a dependency is not merged |
| `bbn-queue.mjs` | 0, 2 | Read-only; predicts conflicts with `git merge-tree` |
| `bbn-report.mjs` | 0, 1, 2 | 1 only with `--strict` |
| `bbn-config-check.mjs` | 0, 1 | |
| `bbn-run.mjs` | 0, 1, 2 | 1 = `verify` failed or an internal error; a stopped stream is an action, not an exit code |
| `bbn-codex.sh` | 0, 1, 2, 3 | 3 = Codex CLI not installed (hand the work to `claude-code`); limit `codex.timeoutSec` (3600 s) |

Network calls in scripts: `git fetch origin` (merge, worktree-new; failures tolerated), `git push` and `gh pr create` only for `bbn-merge.sh --apply --pr`, `claude mcp list` in the doctor, and the Codex CLI's own API calls in `bbn-codex.sh`. `GIT_TERMINAL_PROMPT=0` is set so git never waits for credentials.
