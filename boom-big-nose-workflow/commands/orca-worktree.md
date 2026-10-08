---
description: Create an isolated Orca feature worktree (port, .env.worktree, ownership map)
argument-hint: <feature-slug>
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-new.sh $ARGUMENTS` (ask for a short lowercase slug if none was given). Report the worktree path, branch, start ref and dev port, then remind: fill `.orca/ownership.json` paths, use DB branch `wt-<slug>`, never run migrations on a shared writable DB.
