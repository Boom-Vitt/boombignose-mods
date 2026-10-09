---
description: BBN merge queue - order branches by plan deps, readiness, predicted conflicts and size (read-only)
---

Run `node ${CLAUDE_PLUGIN_ROOT}/scripts/bbn-queue.mjs` from inside the repo (`--base <ref>` if needed). It predicts conflicts with `git merge-tree` without touching any checkout. Report the order, the next branch to merge, and every predicted conflict with who should resolve it (codex) and in which order.
