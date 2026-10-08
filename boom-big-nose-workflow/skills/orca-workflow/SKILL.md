---
name: orca-workflow
description: Use when the user mentions Orca, Boom Big Nose Workflow, coordinating Grok Build / Claude Code / Codex agents, parallel worktrees, a plan checkpoint, review gate, merge order, merging agent branches, or running a change through SDLC phases.
---

# Orca workflow (v0.4)

1. `orca-orchestrator` is the hub. Start with `/orca-doctor` if setup is unknown (every problem has a `fix:` hint).
2. **Plan checkpoint** with `/orca-plan`: `grok-build` writes `.orca/plan.json` (streams, owned paths, dependsOn, acceptance), `check`, show the user, `accept` only after an explicit OK, then `apply --apply` creates the worktrees in dependency order.
3. Single ad-hoc stream without a plan: `/orca-worktree <slug>` (port, `.env.worktree`, `.orca/ownership.json`).
4. Implement with `claude-code`; integrate and resolve conflicts with `codex`. Budgets in `orca.config.json`; `maxTurns` is enforced per agent. Record each run: `orca-ledger.sh agent <role> --turns N --status ok|partial|failed`.
5. `/orca-queue` for merge order and predicted conflicts; `/orca-status` for a quick overview.
6. `/orca-review` -> `orca-gate.sh` + `orca-reviewer` verdict recorded.
7. `/orca-merge` (dry-run) -> `--apply` (local merge; refuses while a plan dependency is unmerged) or `--apply --pr` (draft PR). Never force-push.
8. `/orca-cleanup` removes merged worktrees; `/orca-report` shows turns vs budget.

Exit codes (all scripts): 0 ok, 1 check failed, 2 usage, 3 refused by policy, 4 conflict -> codex, 5 stale review. Quickstart: `docs/QUICKSTART.en.md` / `docs/QUICKSTART.md` (Thai).

## MCP routing and fallback
| Need | First choice | Fallback |
|---|---|---|
| Research, news, comparisons (Orca, grok-build) | Perplexity MCP | WebSearch + WebFetch |
| Library/API docs (claude-code, codex, reviewer) | Context7 MCP | WebFetch official docs |

Both MCPs are optional. If one is missing or unauthenticated, use the fallback and say so. Never ask for or print API keys.

## SDLC phases
Each phase ends with an exit criterion; do not start the next phase until it holds.

| Phase | Orca step | Exit criterion |
|---|---|---|
| Requirements | hub agrees goal, non-goals and success criteria with the user | user confirms; every stream gets testable acceptance checks |
| Design | `/orca-plan`: streams, owned paths, dependsOn, risks; ADR in `docs/decisions/` for lasting decisions | `check` passes and the user says OK, then `accept` |
| Build | `apply --apply`, one worktree per stream (`claude-code`), integration (`codex`) | the stream's acceptance checks pass; run recorded in the ledger |
| Test and review | `/orca-review`: `orca-gate.sh` (lint/typecheck/test), then an independent `orca-reviewer` | gate exit 0 (exit 2 explained) and APPROVE on the current patch |
| Release | `/orca-queue` order, then `/orca-merge` dry-run, `--apply` or `--apply --pr` | merged with no force-push; deploying stays the project's own owner-approved step |
| Maintain | `/orca-cleanup`, `/orca-report`, ADR updates | merged worktrees removed; budget use and failures reported |

Principles: acceptance checks are written at plan time, not after the code. Every merge traces back: goal, stream, acceptance, gate, verdict, merge, ledger. A changed plan is accepted again before `apply`; any new commit makes the review stale (exit 5). Nobody approves their own plan or code. A failure goes back to the phase that owns it: REQUEST_CHANGES to Build, conflict (exit 4) to `codex` then review, stale review (exit 5) to review, wrong scope or design to a re-plan.

## Codex
- `${CLAUDE_PLUGIN_ROOT}` is this plugin's folder, two levels above this file. Codex does not set it: substitute the path. The scripts find their own files.
- Codex has no plugin slash commands. For `/orca-<step>`, read `commands/orca-<step>.md` in the plugin and follow it, with `$ARGUMENTS` = the user's arguments.
- The roles in `agents/<role>.md` are briefs: play them in turn, or in Codex subagents when enabled. The reviewer never shares the context that wrote the code: use a fresh subagent or `codex exec -s read-only -C <worktree> "<review brief>"`.
- Worktrees are created next to the repo (`<repo>-<slug>`) and git writes to `.git`, so the sandbox may ask for approval.
- `orca-doctor.sh` reads `claude mcp list`. In Codex check `codex mcp list` and sign in with `codex mcp login perplexity`.

Details: `docs/orca-architecture.md`. Diagram with the SDLC mapping: `docs/workflow-diagram.md`.
