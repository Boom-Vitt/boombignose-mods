# BBN Quickstart (English)

[ภาษาไทย](QUICKSTART.md)

Since v0.5, BBN runs on autopilot: install it, then ask for what you want in plain words. Part A is the automatic path; part B is the manual `/bbn-*` path, one step at a time, which still works.

# A. Autopilot

## 1. Install and check

```bash
claude plugin marketplace add Boom-Vitt/boombignose-mods
claude plugin install boom-big-nose-workflow@boombignose-mods
```

Restart Claude Code, then in your repo type `/bbn-doctor`. Every WARN/FAIL line comes with a `fix:` hint. You need git 2.39+ and node.

The Codex CLI is optional. With it, the `codex` role hands multi-file work to Codex and the reviewer gets a Codex second opinion:

```bash
npm install -g @openai/codex
codex login
```

Without it, `/bbn-doctor` warns, the `codex` role's streams go to `claude-code`, and the reviewer reviews alone. Model and effort: `bbn.config.json` → `codex` (`gpt-6.1-sol`, reasoning `xhigh`), or `BBN_CODEX_MODEL` / `BBN_CODEX_EFFORT`.

Perplexity is optional: `/mcp` -> `plugin:boom-big-nose-workflow:perplexity` -> sign in. Without it, the hub uses WebSearch.

## 2. Ask for the goal

In a git repo, describe the goal in plain words, for example:

```text
Add card checkout: an order API and a checkout page, with tests. No coupons.
```

No slash command is needed: the `bbn-workflow` skill starts on its own for a goal that spans several files or parts (not for questions or one-line edits). For a fully automatic session, start Claude Code with `claude --agent boom-big-nose-workflow:bbn-orchestrator`. You can also just say "use BBN".

## 3. What it does

1. **Plan.** BBN, the hub (Claude Opus), writes `.bbn/plan.json` (never committed): streams, owned paths, `dependsOn`, and acceptance commands that fail until the work is done. See the example below.
2. **Plan approval.** `bbn-reviewer` (Claude Opus) checks the plan and approves it, or sends it back to the hub with a fix list.
3. **Build.** The harness (`scripts/bbn-run.mjs`) creates one worktree per stream in dependency order. `claude-code` (Claude Sonnet) or `codex` (the Codex CLI, driven by Claude Haiku) builds each stream and commits.
4. **Checks.** The harness runs the stream's acceptance checks and the gate (lint/typecheck/test) on that exact commit. A failure goes back to the builder as `fix`.
5. **Review.** `bbn-reviewer` reviews the branch with a Codex second opinion. On APPROVE the harness merges it into your **local** base, one branch at a time in plan order. A conflict goes to `codex`, and the branch is checked and reviewed again.
6. **Verify.** After the last merge the harness removes the merged worktrees and runs every acceptance check plus the gate on the merged base. Then BBN reports each stream, the verify result, the local base commit and turns used vs budget.

Nothing is pushed: pushing, PRs and deploying stay your call. A stream that fails its checks or review 3 times, or a step that makes no progress, stops; BBN tells you which stream and why, and keeps going with the others.

Example plan:

```json
{
  "version": 1,
  "title": "Checkout",
  "status": "draft",
  "goal": "Users can pay by card",
  "nonGoals": ["coupons"],
  "base": "main",
  "streams": [
    { "slug": "checkout-api", "role": "claude-code", "summary": "Order creation API",
      "paths": ["src/api/checkout/"], "dependsOn": [],
      "acceptance": ["npm test -- src/api/checkout"] },
    { "slug": "checkout-ui", "role": "claude-code", "summary": "Checkout page",
      "paths": ["src/app/checkout/"], "dependsOn": ["checkout-api"],
      "acceptance": ["npm test -- src/app/checkout"] }
  ],
  "risks": ["order schema change"]
}
```

Each `acceptance` entry is a shell command run from the worktree root; exit 0 means pass.

## 4. Turn on checkpoints

By default nothing waits for you between the request and the final report. To get the human checkpoints back, set `automation` in the plugin's `bbn.config.json` (it is the plugin's own file, so check it again after a plugin update):

```json
"automation": { "planApproval": "user", "merge": "ask" }
```

- `planApproval: "user"`: BBN shows the plan and waits for your OK before any worktree is created.
- `merge: "ask"`: BBN asks before each merge into the local base.

Use either one or both.

## 5. Watch or preview

- `/bbn-status`: every worktree, ahead/behind, gate and review state.
- `/bbn-report`: gates, reviews, merges and turns used per agent vs budget.
- To see the next steps without changing anything, ask Claude to run `node ${CLAUDE_PLUGIN_ROOT}/scripts/bbn-run.mjs` (no `--apply`). `bbn-run.mjs verify` runs every acceptance check and the gate on the base now.

# B. Manual, one step at a time

The `/bbn-*` commands still run each step yourself. Every step that changes something is a dry-run first.

## 1. Plan (the checkpoint)

```text
/bbn-plan init "Checkout"
```

BBN (the hub) writes the plan to `.bbn/plan.json`, like the example in A.3.

`/bbn-plan check` validates: schema, stream count within budget, at least `minAcceptanceChecks` acceptance checks per stream (default 1), relative paths only, known and acyclic `dependsOn`, and **no two streams owning the same path** unless one depends on the other.

Review the plan and say OK. BBN then runs `accept` and `apply --apply`, which creates the worktrees in dependency order, each with `.bbn/ownership.json`. Edit the plan after accepting and you must `check` + `accept` again (apply refuses with exit 3).

## 2. Work in parallel

- `claude-code` or `codex` works in its own worktree (own port, `.env.worktree`, DB branch `wt-<slug>`).
- After each agent returns, BBN records its turns in the ledger (`bbn-ledger.sh agent ...`).
- `/bbn-status` for an overview.

## 3. Merge order

```text
/bbn-queue
```

Ordered by plan dependencies -> ready (gate + review match the current commit) -> predicted conflict with base -> conflicts between branches -> size. Conflicts are predicted with `git merge-tree` without touching any checkout. The `next:` line is the branch to merge first.

## 4. Review and merge

```text
/bbn-review checkout-api
/bbn-merge checkout-api            # dry-run
/bbn-merge checkout-api --apply    # rebase -> gate -> fingerprint check -> merge into the local base
```

- exit 3: refused (no APPROVE, dirty tree, plan dependency not merged yet)
- exit 4: rebase conflict -> hand to `codex`, then review again
- exit 5: code changed after the review -> review again

BBN never pushes the base and never force-pushes. For a PR: `--apply --pr` (draft).

## 5. Report and clean up

```text
/bbn-report     # gates/reviews/merges and turns used per agent vs budget
/bbn-cleanup    # dry-run; --apply removes merged worktrees
```

All exit codes: [exit-codes.md](exit-codes.md)
