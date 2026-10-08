---
description: BBN plan checkpoint - write .bbn/plan.json (streams, ownership, deps, acceptance), validate, accept, create worktrees
argument-hint: [init|check|accept|apply|show] [title]
---

The plan is the checkpoint before any fan-out. Plugin script: `node ${CLAUDE_PLUGIN_ROOT}/scripts/bbn-plan.mjs`.

1. No plan yet: `bbn-plan.mjs init --title "<title>"`, then ask `grok-build` for the plan as JSON matching `${CLAUDE_PLUGIN_ROOT}/bbn.plan.schema.json` and write it to `.bbn/plan.json` in the main checkout.
2. `bbn-plan.mjs check`: fix every error. Two streams may own the same path only if one `dependsOn` the other.
3. Show the plan (`bbn-plan.mjs show`) to the user and wait for an explicit OK. Then `bbn-plan.mjs accept`.
4. `bbn-plan.mjs apply` (dry-run), then `bbn-plan.mjs apply --apply` to create the worktrees with ownership maps.
5. If the plan must change later: edit, `check`, show, `accept` again (apply refuses a changed plan until re-accepted).

Arguments given: $ARGUMENTS
