---
name: git-worktree
description: Create or manage BBN git worktrees (one feature per worktree) with per-worktree port, env and DB isolation.
---

# git worktree (BBN v0.5)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/worktree-new.sh <feature-slug> [--base <ref>]
```

In Codex, `${CLAUDE_PLUGIN_ROOT}` is not set: it is this plugin's folder, two levels above this file.

- One feature, one worktree, one agent stream. Never let two agents edit the same working tree.
- Base: `origin/dev`, else `origin/main`, `dev`, `main`, `master` (or `--base`).
- Isolation per worktree: `BBN_DEV_PORT`/`PORT` in `.env.worktree` (copied from `.env` when present), DB branch `wt-<slug>` (e.g. a Supabase branch), base migrations before feature migrations, no shared writable DB.
- `.env.worktree` and `.bbn/` are added to the repo's local `info/exclude`, so they never show up in commits.
- Budget: refuses beyond `maxParallelWorktrees`.
- On autopilot the harness creates them for you: `bbn-run.mjs --apply` makes every stream's worktree in dependency order once the plan is accepted.
- With a plan, run by hand, prefer `/bbn-plan apply --apply`: it creates every stream's worktree in dependency order and fills the ownership map.
- Branches are created without upstream tracking; `--pr` pushes with `-u` to the feature's own remote branch.
- Done? `/bbn-merge`, then `/bbn-cleanup`.
