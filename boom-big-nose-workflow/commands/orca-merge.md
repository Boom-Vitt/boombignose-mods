---
description: Merge a reviewed Orca branch - dry-run by default; rebase, gate, review check; never force-push
argument-hint: [--apply] [--pr] [--base <ref>]
---

From the feature worktree, run `${CLAUDE_PLUGIN_ROOT}/scripts/orca-merge.sh $ARGUMENTS`.

- No arguments: dry-run plan and refusal reasons. Show it to the user before running `--apply`.
- `--apply`: rebase on base, gate on the rebased tree, check the review still matches, `merge --no-ff` into the local base branch. Nothing is pushed.
- `--apply --pr`: same checks, then push the feature branch (no force) and open a **draft** PR with `gh`. Only when the user asked for a PR.
- Exit 4 (conflict): hand to `codex`, then `/orca-review` again. Exit 5 (stale review): `/orca-review` again.
- Afterwards suggest `/orca-cleanup`.
