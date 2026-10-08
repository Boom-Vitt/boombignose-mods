# Orca Quickstart (English)

[ภาษาไทย](QUICKSTART.md)

From install to your first merged feature in about 10 minutes. Every step that changes something is a dry-run first.

## 1. Install and check

```bash
claude plugin marketplace add Boom-Vitt/claude-mods-boombignose
claude plugin install boom-big-nose-workflow@claude-mods-boombignose
```

Restart Claude Code, then in your repo type `/orca-doctor`. Every WARN/FAIL line comes with a `fix:` hint. You need git 2.38+ and node.

Perplexity is optional: `/mcp` -> `plugin:boom-big-nose-workflow:perplexity` -> sign in. Without it, agents use WebSearch.

## 2. Plan (the checkpoint)

```text
/orca-plan init "Checkout"
```

Orca asks `grok-build` to write the plan to `.orca/plan.json` (never committed). Example:

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
      "acceptance": ["POST /checkout returns 201", "order total has a test"] },
    { "slug": "checkout-ui", "role": "claude-code", "summary": "Checkout page",
      "paths": ["src/app/checkout/"], "dependsOn": ["checkout-api"],
      "acceptance": ["pay leads to the success page", "declined card shows an error"] }
  ],
  "risks": ["order schema change"]
}
```

`/orca-plan check` validates: schema, stream count within budget, at least 2 acceptance checks, relative paths only, known and acyclic `dependsOn`, and **no two streams owning the same path** unless one depends on the other.

Review the plan and say OK. Orca then runs `accept` and `apply --apply`, which creates the worktrees in dependency order, each with `.orca/ownership.json`. Edit the plan after accepting and you must `check` + `accept` again (apply refuses with exit 3).

## 3. Work in parallel

- `claude-code` works in its own worktree (own port, `.env.worktree`, DB branch `wt-<slug>`).
- After each agent returns, Orca records its turns in the ledger (`orca-ledger.sh agent ...`).
- `/orca-status` for an overview.

## 4. Merge order

```text
/orca-queue
```

Ordered by plan dependencies -> ready (gate + review match the current commit) -> predicted conflict with base -> conflicts between branches -> size. Conflicts are predicted with `git merge-tree` without touching any checkout. The `next:` line is the branch to merge first.

## 5. Review and merge

```text
/orca-review checkout-api
/orca-merge checkout-api            # dry-run
/orca-merge checkout-api --apply    # rebase -> gate -> fingerprint check -> merge into the local base
```

- exit 3: refused (no APPROVE, dirty tree, plan dependency not merged yet)
- exit 4: rebase conflict -> hand to `codex`, then review again
- exit 5: code changed after the review -> review again

Orca never pushes the base and never force-pushes. For a PR: `--apply --pr` (draft).

## 6. Report and clean up

```text
/orca-report     # gates/reviews/merges and turns used per agent vs budget
/orca-cleanup    # dry-run; --apply removes merged worktrees
```

All exit codes: [exit-codes.md](exit-codes.md)
