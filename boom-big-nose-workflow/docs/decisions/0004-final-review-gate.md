# ADR-0004: Integration branch and final review gate

- **Status:** Accepted
- **Date:** 2026-10-11
- **Deciders:** Boom + BBN workflow maintainers

## Context

Up to v0.5 each stream was reviewed alone and merged straight into the local base. Nobody looked at the streams together, so integration mistakes, a leftover secret in history, or a file outside every stream's scope reached the base before anyone saw the whole change, and a bad merge could not be backed out without rewriting the base.

## Decision

1. **A per-run integration branch.** `bbn-plan.mjs accept` names it `bbn/<slug(title)>-<hash6>` and keeps the name on a re-accept (a new name if the branch already has its final merge). The harness creates it from the target (the plan `base`) with `--no-track`. Streams branch from it, are checked and reviewed against it, and merge into it. `bbn-merge.sh` refuses (exit 3, `base-not-integration`) to merge a plan stream into any other base. The target is untouched until the end.
2. **A final review of the whole diff.** After the last stream, the harness removes the stream worktrees, opens a final worktree on the integration branch, runs `verify` (every acceptance check, the gate, and a paths check against the union of all streams' paths), then returns a `final-review` action (`base` = target). `bbn-reviewer` reviews the whole `target...integration` diff with a Codex second opinion and records the verdict against the target. The verdict is bound to the patch fingerprint computed against the target.
3. **One merge, never a rebase.** APPROVE leads to one `bbn-merge.sh --apply --base <target> --no-rebase` (asked first when `automation.merge` is `ask`). If the target moved, the merge exits 4 and `codex` merges the target into the integration branch (`git merge`): the integration branch holds merge commits, and a rebase would rewrite what was reviewed. REQUEST_CHANGES becomes a `replan` that adds a fix stream under a new slug and keeps the merged streams in the plan; after `hardStopOnRepeatedFailures` rejections, or a BLOCK, the run stops.
4. **Guardrails on the way in.** A secret scan (`bbn-plan.mjs scan`) over the net diff and every commit, and path ownership per stream, run in each stream's check and again in `bbn-merge.sh` (fail closed). The plan check refuses owned paths that are gitignored or untracked in the main checkout.

## Consequences

- `main` changes once per run, only after an independent review of the combined diff; backing out is one revert of one merge commit.
- Cost: one more review and one more `verify` per run; plans cannot be at `maxParallelWorktrees` if a fix stream may be needed (merged streams still count).
- Known limitations: the plan check reads the main checkout's working tree, not the plan `base` branch; `integration === target` is not rejected yet; octopus merges fail the scan closed (unscanned) and patches over 64MB fail with exit 2.
- Not done: mechanical enforcement that the final reviewer is a different agent from the stream authors; a maximum diff size beyond the 64MB scan buffer; scanning octopus merges.
- A plan accepted under v0.5 has no integration name; the harness asks for `accept` again (`plan needs accept again to name its integration branch (v0.6)`).
