---
description: Orca plan checkpoint - write .orca/plan.json (streams, ownership, deps, acceptance), validate, accept, create worktrees
argument-hint: [init|check|accept|apply|show] [title]
---

The plan is the checkpoint before any fan-out. Plugin script: `node ${CLAUDE_PLUGIN_ROOT}/scripts/orca-plan.mjs`.

1. No plan yet: `orca-plan.mjs init --title "<title>"`, then ask `grok-build` for the plan as JSON matching `${CLAUDE_PLUGIN_ROOT}/orca.plan.schema.json` and write it to `.orca/plan.json` in the main checkout.
2. `orca-plan.mjs check`: fix every error. Two streams may own the same path only if one `dependsOn` the other.
3. Show the plan (`orca-plan.mjs show`) to the user and wait for an explicit OK. Then `orca-plan.mjs accept`.
4. `orca-plan.mjs apply` (dry-run), then `orca-plan.mjs apply --apply` to create the worktrees with ownership maps.
5. If the plan must change later: edit, `check`, show, `accept` again (apply refuses a changed plan until re-accepted).

Arguments given: $ARGUMENTS
