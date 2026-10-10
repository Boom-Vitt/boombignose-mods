---
description: Merge a reviewed BBN branch - dry-run by default; rebase, gate, review check; never force-push
argument-hint: [--apply] [--pr] [--base <ref>] [--no-rebase]
---

From the feature worktree, run `${CLAUDE_PLUGIN_ROOT}/scripts/bbn-merge.sh $ARGUMENTS`.

- No arguments: dry-run plan and refusal reasons. Show it to the user before running `--apply`.
- `--apply`: secret scan (`bbn-plan.mjs scan`, refuses with exit 3 on a hit or when the scan cannot run), rebase on base, gate on the rebased tree, check the review still matches, `merge --no-ff` into the local base branch. Nothing is pushed.
- `--no-rebase`: if the base moved, do not rebase: exit 4 so the base is merged into the branch (the harness uses it for the final merge of the integration branch).
- A branch that is a stream of an accepted plan can only merge into the plan's integration branch (`--base` any other: exit 3); the integration branch itself merges into the target after `final-review`.
- `--apply --pr`: same checks, then push the feature branch (no force) and open a **draft** PR with `gh`. Only when the user asked for a PR.
- Exit 4 (conflict or, with `--no-rebase`, base moved): hand to `codex`, then `/bbn-review` again. Exit 5 (stale review): `/bbn-review` again.
- Afterwards suggest `/bbn-cleanup`.
