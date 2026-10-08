---
description: BBN status - worktrees, branches, ahead/behind base, gate and review state, overlapping files
---

Run `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-status.sh` from inside the repo (add `--base <ref>` if needed). Summarise: which branches are ready to merge (gate pass + APPROVE for the current commit), which are stale (`*`), and any files touched by more than one branch with a suggested merge order.
