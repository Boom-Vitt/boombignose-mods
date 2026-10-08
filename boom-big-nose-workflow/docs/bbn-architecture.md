# BBN architecture - Boom Big Nose Workflow (v0.4.0)

BBN coordinates several AI agent roles in one workflow: a hub plans and dispatches, each feature gets its own git worktree, and nothing reaches the base branch without passing a gate. It follows the "Getting started with BBN: combining Grok Build, Claude Code and Codex in the same workflow" infographic (fifty-three agents, Perplexity MCP and Context7 MCP), extended with review, merge and isolation rules.

> "Grok Build", "Claude Code" and "Codex" here are **roles implemented as Claude Code subagents** in this plugin, not logins to those external products.

## Flow

```mermaid
flowchart TB
  goal([Goal + success criteria]) --> O[bbn-orchestrator]
  O --> GB[grok-build: plan]
  GB --> PL[/bbn-plan check<br/>.bbn/plan.json: streams, ownership, deps, acceptance/]
  PL --> CP{user OK?}
  CP -- reject / re-plan --> GB
  CP -- accept + apply --> WT[/worktree per stream, in dependency order<br/>port, .env.worktree, ownership.json/]
  WT --> CC[claude-code: implement]
  WT --> CX[codex: integrate]
  CC --> Q[/bbn-queue<br/>deps, ready, merge-tree conflicts, size/]
  CX --> Q
  Q --> RV[/bbn-review<br/>bbn-gate.sh + bbn-reviewer/]
  RV -- REQUEST_CHANGES / BLOCK --> CC
  RV -- APPROVE recorded --> MG[/bbn-merge dry-run/]
  MG --> AP{--apply}
  AP -- plan dependency not merged exit 3 --> Q
  AP -- rebase conflict exit 4 --> CX
  AP -- content changed exit 5 --> RV
  AP -- gate fails exit 1 --> CC
  AP -- ok --> BASE[(local base branch<br/>not pushed)]
  AP -- --pr --> PR[(draft PR on GitHub)]
  BASE --> CL[/bbn-cleanup/]
  CL --> RP[/bbn-report<br/>turns vs budget/]

  LED[(ledger<br/>common-git-dir/bbn/runs.jsonl)]
  PL -.-> LED
  RV -.-> LED
  AP -.-> LED
  O -.agent turns.-> LED
  LED -.-> RP

  PPLX[(Perplexity MCP<br/>optional)] -.research.-> GB
  PPLX -.-> O
  WS[(WebSearch / WebFetch)] -.fallback.-> GB
  C7[(Context7 MCP<br/>optional)] -.docs.-> CC
  C7 -.-> CX
  C7 -.-> RV
```

## Roles

| Agent | Job | Tools | maxTurns |
|---|---|---|---|
| `bbn-orchestrator` | hub, plan checkpoint, budgets, merge order | all | 60 |
| `grok-build` | plan + research | all except Write/Edit/NotebookEdit | 25 |
| `claude-code` | implement/refactor in one worktree | all | 40 |
| `codex` | multi-file integration, conflict owner | all | 40 |
| `bbn-reviewer` | gate + recorded verdict | all except Write/Edit/NotebookEdit | 25 |

`maxTurns` in each agent's frontmatter is enforced by Claude Code; `bbn.config.json` holds the same numbers and `bbn-config-check.mjs` fails if they drift.

## Gate and merge

- `bbn-gate.sh`: `BBN_GATE_CMD` or `.bbn/gate.sh` if present, else auto-detect flutter / pnpm / yarn / bun / npm (lint, typecheck, test), cargo, go, pytest. Exit 0 pass, 1 fail, 2 nothing to run. The result is stored for the current commit in the worktree's git dir (`<git-dir>/bbn/gate.json`), never in the work tree.
- `bbn-review-record.sh`: stores the reviewer's verdict with a **patch fingerprint** (`git patch-id` of the branch diff). A clean rebase keeps the fingerprint; new commits or conflict edits change it, so the approval no longer counts.
- `bbn-merge.sh`: dry-run by default. `--apply`: refuse without APPROVE or with a dirty tree, refuse if the fingerprint changed, rebase on base (conflict, so exit 4 to Codex), re-check the fingerprint, run the gate on the rebased tree, then `merge --no-ff` into the local base in whichever worktree has it checked out (or a temporary one). It never pushes the base branch and never force-pushes. `--apply --pr` pushes the feature branch (no force) and opens a draft PR with `gh`.
- `bbn-status.sh`: every worktree with ahead/behind, dirty, gate/review state (`*` = recorded for an older commit), and files changed on more than one branch, the input for merge order.
- `bbn-plan.mjs`: the plan checkpoint as a file (see "Plan, queue, ledger").
- `bbn-queue.mjs`: merge order with predicted conflicts (read-only).
- `bbn-cleanup.sh`: dry-run by default; removes clean worktrees of merged branches; `--delete-branches` uses `git branch -d` (merged only); `--include-unmerged` removes clean unmerged worktrees but keeps their branches.

## Plan, queue, ledger (v0.4)

- **Plan** `<main worktree>/.bbn/plan.json` (schema `bbn.plan.schema.json`, git-excluded). `check`: schema, stream count <= `maxParallelWorktrees`, `minAcceptanceChecks`, repo-relative paths, known dependencies without cycles, and file ownership: two streams may own overlapping paths only when one depends on the other (then it is a warning, because they merge in order). `accept` stores `planHash`; `apply --apply` refuses an unaccepted or edited plan (exit 3) and creates worktrees in topological order, writing role, paths, dependencies and acceptance into `.bbn/ownership.json`.
- **Queue** `bbn-queue.mjs` runs `git merge-tree --write-tree` for each branch against the base and for each pair of branches that touch the same files, without touching any checkout. Order: plan dependencies, then ready (gate + review recorded for the current commit), base conflicts, pairwise conflicts, overlaps, diff lines. `bbn-merge.sh --apply` enforces the dependency part (exit 3; `--ignore-order` overrides).
- **Ledger** `<common-git-dir>/bbn/runs.jsonl`: one JSON line per event, shared by all worktrees, never committed. Script events: `worktree.create`, `gate`, `review`, `merge` (`result` = merged / refused / conflict / stale_review / gate_failed / draft_pr), `merge.dryrun`, `plan.accept`, `plan.apply`, `cleanup`. The orchestrator adds `agent` events (`role`, `turns`, `status`). `bbn-report.mjs` sums them and flags runs that hit `maxTurns` (`partial`), failed, or exceeded budget; `--strict` exits 1 on any of these.
- **Exit codes** are shared by every script: [exit-codes.md](exit-codes.md).

## Isolation per worktree

`worktree-new.sh` gives each worktree a deterministic dev port (`portBase + cksum(slug) % portRange`), a `.env.worktree` (copied from `.env` when present, plus `BBN_DEV_PORT`/`PORT`), and `.bbn/ownership.json` (paths, DB branch `wt-<slug>`). Both are added to the repo's local `info/exclude`. Rules: one DB branch per worktree (for Supabase, a preview branch), base migrations before feature migrations, never a shared writable DB. The script refuses beyond `maxParallelWorktrees`.

## MCP routing

| Server | Used by | For | Auth | Fallback |
|---|---|---|---|---|
| Perplexity (`api.perplexity.ai/mcp`) | orchestrator, grok-build | research, current facts | sign-in via `/mcp` (OAuth) | WebSearch + WebFetch |
| Context7 (`mcp.context7.com/mcp`) | claude-code, codex, reviewer | library/API docs | none (optional key) | WebFetch official docs |

## Weakness -> fix

| Weakness (v0.1) | Fix | Since |
|---|---|---|
| No review/test gate before merge | `bbn-reviewer`, `bbn-gate.sh`, `/bbn-review`; merge requires a recorded APPROVE | 0.2.0, enforced in 0.3.0 |
| No conflict process | ownership maps, `/bbn-status` overlap report, rebase-before-merge, Codex owns conflicts, patch fingerprint forces re-review | 0.2.0 / 0.3.0 |
| BBN single point of failure | plan checkpoint + re-plan, independent reviewer, decision log | 0.2.0 |
| No budgets | `bbn.config.json` + enforced `maxTurns`; worktree cap in `worktree-new.sh` | 0.2.0 / 0.3.0 |
| Shared DB/ports/env | per-worktree port, `.env.worktree`, DB branch rule, migration order | 0.2.0 |
| MCP use undefined | routing table; agents can now actually reach MCP (denylist, not allowlist); fallbacks; doctor fix hints | 0.2.0 / 0.3.0 / 0.4.0 |
| Plan checkpoint only in the prompt | `.bbn/plan.json` + `bbn-plan.mjs` (accept hash, apply refuses changed plans) | 0.4.0 |
| Merge order a judgement call; conflicts found at rebase | `/bbn-queue` with `git merge-tree` prediction; merge refuses unmerged plan dependencies | 0.4.0 |
| Budgets enforced but invisible | run ledger + `/bbn-report` (turns vs `maxTurns`) | 0.4.0 |
| A hung gate step could block forever | per-step timeout `stepTimeoutSec` | 0.4.0 |

## Changes in v0.3.0

- **Perplexity 401 fixed**: the empty `Bearer ${PERPLEXITY_API_KEY}` header (key not set) caused 401 and blocked OAuth. The plugin now uses sign-in; API key is an opt-in route (README). See ADR-0002.
- **Agents could not use MCP**: `tools:` allowlists hid MCP tools; switched to `disallowedTools`. `color: magenta` (invalid) -> `purple`. `maxTurns` added.
- **Merge rewritten**: v0.2 ran the gate before rebasing and tried to `checkout` the base inside the feature worktree (fails when base is checked out elsewhere). Now: rebase, then gate, then fingerprint check, then merge in the base worktree.
- **New**: `/bbn-doctor`, `/bbn-status`, `/bbn-cleanup`, `bbn-review-record.sh`, draft-PR path, GitHub Actions template, JSON schema + validator, bash test suite, CHANGELOG.

## Changes in v0.4.0

- **Plan checkpoint enforced** by `/bbn-plan` (ADR-0003).
- **Merge queue** with predicted conflicts, and ordered merges.
- **Ledger + report** of turns per agent vs budget.
- **Hardening**: gate step timeout, shared exit codes, `GIT_TERMINAL_PROMPT=0`, shellcheck-clean scripts, doctor fix hints and 401 guard, feature branches created without upstream tracking (cleanup could not delete them).
- **Tests**: `tests/smoke.sh` end-to-end dry run in a temp repo, plus unit tests for every new script.

## Decision log

`docs/decisions/` holds this plugin's ADRs (0001 review gate, 0002 Perplexity sign-in, 0003 plan file + ledger + merge queue) and `ADR-TEMPLATE.md` for projects that use BBN.
