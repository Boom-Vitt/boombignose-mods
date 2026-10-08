# ADR-0001: Require review/QA gate before merge

- **Status:** Accepted
- **Date:** 2026-10-08
- **Deciders:** Boom + Orca workflow maintainers

## Context

In v0.1, Orca could coordinate parallel worktrees but had no mandatory test/lint/typecheck gate or independent reviewer before merging feature branches. Bad plans and broken trees could land on the base branch.

## Decision

Before any `/orca-merge --apply`:
1. `scripts/orca-gate.sh` must exit 0 (or an explicit human override is documented — default refuse).
2. `orca-reviewer` must return `VERDICT: APPROVE`.
3. After conflict resolution by Codex, the gate must be re-run.

## Consequences

- Slower merges, higher confidence.
- Scripts default to dry-run and never force-push.
- Ownership maps reduce silent overlapping edits.

## Alternatives considered

1. Honor-system “run tests yourself” in agent prompts only — rejected as unenforceable.
2. CI-only gate with no local script — deferred as complementary, not a replacement for local `/orca-review`.
