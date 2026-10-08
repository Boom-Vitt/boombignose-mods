---
name: git-worktree
description: Create or manage Orca git worktrees (one feature per worktree) with per-worktree port, env and DB isolation.
---

# git worktree (Orca v0.4)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/worktree-new.sh <feature-slug> [--base <ref>]
```

In Codex, `${CLAUDE_PLUGIN_ROOT}` is not set: it is this plugin's folder, two levels above this file.

- One feature, one worktree, one agent stream. Never let two agents edit the same working tree.
- Base: `origin/dev`, else `origin/main`, `dev`, `main`, `master` (or `--base`).
- Isolation per worktree: `ORCA_DEV_PORT`/`PORT` in `.env.worktree` (copied from `.env` when present), DB branch `wt-<slug>` (e.g. a Supabase branch), base migrations before feature migrations, no shared writable DB.
- `.env.worktree` and `.orca/` are added to the repo's local `info/exclude`, so they never show up in commits.
- Budget: refuses beyond `maxParallelWorktrees`.
- With a plan, prefer `/orca-plan apply --apply`: it creates every stream's worktree in dependency order and fills the ownership map.
- Branches are created without upstream tracking; `--pr` pushes with `-u` to the feature's own remote branch.
- Done? `/orca-merge`, then `/orca-cleanup`.
