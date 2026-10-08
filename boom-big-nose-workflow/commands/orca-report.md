---
description: Orca report - gates, reviews, merges, worktrees and per-agent turn use vs budget from the run ledger
argument-hint: [--since <ISO date>]
---

Run `node ${CLAUDE_PLUGIN_ROOT}/scripts/orca-report.mjs $ARGUMENTS` and summarise it. Call out agents that hit their turn limit (partial) or went over budget, failed gates, and refused merges, with a suggestion for each.
