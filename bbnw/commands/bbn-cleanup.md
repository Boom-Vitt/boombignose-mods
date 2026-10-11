---
description: Remove merged BBN worktrees - dry-run by default; never touches dirty or unmerged work without a flag
argument-hint: [--apply] [--delete-branches] [--include-unmerged]
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-cleanup.sh $ARGUMENTS` from the main checkout. Without `--apply` it only lists what it would remove. Show the dry-run to the user before `--apply`. `--delete-branches` uses `git branch -d` on merged branches only; unmerged branches are never deleted.
