---
description: BBN review gate - run lint/typecheck/test and the bbn-reviewer agent, record the verdict
---

In the feature worktree being reviewed:

1. Ensure everything is committed.
2. Delegate to the `bbn-reviewer` agent with: branch, base, the plan's acceptance checks, and ownership paths.
3. The reviewer runs `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-gate.sh` and records its verdict with `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-review-record.sh`.
4. Report `VERDICT` and findings. Only APPROVE lets `/bbn-merge --apply` proceed; any later commit or conflict edit invalidates the approval.
