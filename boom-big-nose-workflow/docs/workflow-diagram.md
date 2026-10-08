# Orca workflow diagram

How a goal moves through Orca v0.4, from plan to cleanup. Step by step: [QUICKSTART.en.md](QUICKSTART.en.md) · [QUICKSTART.md](QUICKSTART.md) (ไทย). Roles and design: [orca-architecture.md](orca-architecture.md).

```
                        ┌───────────────────────────┐
  you ──── goal ──────▶ │  orca-orchestrator (hub)  │   setup unknown? → /orca-doctor (every problem has a fix: hint)
                        └─────────────┬─────────────┘
                 ┌────────────────────┴────────────────────┐
         several streams                              one ad-hoc stream
                 ▼                                         ▼
 ① /orca-plan                                     /orca-worktree <slug>
   grok-build writes .orca/plan.json                port, .env.worktree,
   (streams · owned paths · dependsOn · acceptance) .orca/ownership.json
   check ─▶ shown to you ─▶ ⏸ waits for your OK
   ─▶ accept ─▶ apply --apply
   (worktrees created in dependency order)
                 └────────────────────┬────────────────────┘
                                      ▼
 ② BUILD     ┌ worktree A ┐   ┌ worktree B ┐   ┌ worktree C ┐
             │ claude-code│   │ claude-code│   │ claude-code│   maxTurns per agent (orca.config.json)
             └─────┬──────┘   └─────┬──────┘   └─────┬──────┘
                   └────── conflict? (exit 4) ──▶ codex integrates and resolves
             each run logged: orca-ledger.sh agent <role> --turns N --status ok|partial|failed
                                      ▼
 ③ /orca-queue   merge order + predicted conflicts   ·   /orca-status quick overview
                                      ▼
 ④ /orca-review  orca-gate.sh (lint/typecheck/test) + orca-reviewer
                 ├─ APPROVE ─────────────────────────────┐
                 └─ REQUEST_CHANGES / BLOCK ─▶ back to ② │
                                      ▼  ◀───────────────┘
 ⑤ /orca-merge   dry-run ─▶ --apply      (local merge; refused while a plan dependency is unmerged)
                         └▶ --apply --pr (draft PR)        never force-push
                                      ▼                    stale review (exit 5) ─▶ back to ④
 ⑥ /orca-cleanup removes merged worktrees   ·   /orca-report turns used vs budget
```

**Exit codes (every script):** 0 ok · 1 check failed · 2 usage · 3 refused by policy · 4 conflict → codex · 5 stale review. Details: [exit-codes.md](exit-codes.md).

**MCP routing:** research → Perplexity (fallback WebSearch + WebFetch) · library/API docs → Context7 (fallback WebFetch of official docs). Both are optional.
