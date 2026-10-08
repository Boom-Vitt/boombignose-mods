#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN merge. Dry-run by default; never force-pushes; never pushes the base branch.
#   bbn-merge.sh                 dry-run: show what would happen and why it would refuse
#   bbn-merge.sh --apply         rebase on base -> gate -> check review -> merge --no-ff into local base
#   bbn-merge.sh --apply --pr    rebase -> gate -> check review -> push feature branch -> gh pr create --draft
# Options: --base <ref>  --allow-empty-gate  --ignore-order (skip plan dependsOn check)
# Exit: 0 ok, 1 gate failed, 2 usage, 3 refused (review/state), 4 conflict (hand to Codex), 5 stale review
set -uo pipefail
BBN_TAG=bbn-merge
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/bbn-common.sh"

APPLY=0; PR=0; BASE_ARG=""; ALLOW_EMPTY=0; IGNORE_ORDER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --pr) PR=1; shift ;;
    --base) BASE_ARG="${2:-}"; shift 2 ;;
    --allow-empty-gate) ALLOW_EMPTY=1; shift ;;
    --ignore-order) IGNORE_ORDER=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) bbn_die "unknown arg: $1" 2 ;;
  esac
done

bbn_require_repo
branch="$(git rev-parse --abbrev-ref HEAD)"
bbn_protected_branch "$branch" && bbn_die "on '$branch': run from the feature branch worktree" 3
git fetch --quiet origin 2>/dev/null || bbn_warn "fetch failed; using local refs"
base="$(bbn_pick_base "$BASE_ARG")"
base_local="${base#origin/}"
sd="$(bbn_state_dir)"
review="$sd/review.json"
verdict="$(bbn_json_get "$review" verdict)"
reviewed_patch="$(bbn_json_get "$review" patch_id)"

if git merge-base --is-ancestor "$base" HEAD; then need_rebase=0; else need_rebase=1; fi

bbn_log "branch=$branch base=$base mode=$([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN)$([ $PR -eq 1 ] && echo ' +PR')"
bbn_log "review=${verdict:-none} rebase_needed=$([ $need_rebase -eq 1 ] && echo yes || echo no) clean=$(bbn_is_clean && echo yes || echo no)"

refuse=""
[ "$verdict" = "APPROVE" ] || refuse="no APPROVE review recorded (run /bbn-review)"
bbn_is_clean || refuse="${refuse:+$refuse; }uncommitted changes"
# Plan order: every stream this one dependsOn must already be merged into base.
if [ "$IGNORE_ORDER" -eq 0 ] && command -v node >/dev/null 2>&1; then
  deps_out="$(node "$HERE/bbn-plan.mjs" deps-merged --branch "$branch" --base "$base" 2>&1)"; deps_rc=$?
  [ "$deps_rc" -eq 3 ] && refuse="${refuse:+$refuse; }$deps_out"
fi

if [ "$APPLY" -eq 0 ]; then
  bbn_log "plan:"
  [ $need_rebase -eq 1 ] && bbn_log "  1. git rebase $base (conflicts -> Codex, then /bbn-review again)"
  bbn_log "  2. bbn-gate.sh on the rebased tree"
  bbn_log "  3. check review patch-id still matches (else re-review)"
  if [ $PR -eq 1 ]; then bbn_log "  4. git push -u origin $branch (no force) + gh pr create --draft --base $base_local"
  else bbn_log "  4. merge --no-ff $branch into local $base_local (not pushed)"; fi
  if [ -n "$refuse" ]; then bbn_log "WOULD REFUSE: $refuse"; bbn_ledger merge.dryrun result=refused "reason=$refuse"; exit 3; fi
  bbn_log "ready; re-run with --apply"; exit 0
fi

[ -n "$refuse" ] && { bbn_ledger merge result=refused "reason=$refuse"; bbn_die "refusing: $refuse" 3; }
[ "$(bbn_patch_id "$base")" = "$reviewed_patch" ] \
  || { bbn_ledger merge result=stale_review; bbn_die "changes differ from what was reviewed (new commits since review). Re-run /bbn-review." 5; }

if [ $need_rebase -eq 1 ]; then
  bbn_log "rebasing onto $base"
  if ! git rebase --quiet "$base"; then
    bbn_warn "rebase conflict. Hand to the codex agent: resolve, git rebase --continue, then /bbn-review again."
    bbn_warn "To back out: git rebase --abort"
    bbn_ledger merge result=conflict stage=rebase
    exit 4
  fi
fi
git merge-base --is-ancestor "$base" HEAD || bbn_die "branch still not based on $base" 3

now_patch="$(bbn_patch_id "$base")"
if [ "$now_patch" != "$reviewed_patch" ]; then
  bbn_die "changes differ from what was reviewed (new commits or conflict edits). Re-run /bbn-review." 5
fi

"$HERE/bbn-gate.sh"; g=$?
if [ $g -eq 2 ] && [ $ALLOW_EMPTY -eq 0 ]; then bbn_die "gate ran no checks; pass --allow-empty-gate if that is intended" 1; fi
[ $g -eq 1 ] && { bbn_ledger merge result=gate_failed; bbn_die "gate failed on the rebased tree" 1; }

if [ $PR -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || bbn_die "gh not installed" 3
  if ! git push -u origin "$branch"; then
    bbn_die "push rejected (branch was rewritten by rebase?). Not forcing. Push a new branch name or resolve manually." 3
  fi
  gh pr create --draft --base "$base_local" --head "$branch" --fill || bbn_die "gh pr create failed" 3
  bbn_ledger merge result=draft_pr "base=$base_local"
  bbn_log "draft PR opened; merge happens on GitHub after review"
  exit 0
fi

# Merge into local base. Prefer the worktree that already has base checked out.
base_wt="$(git worktree list --porcelain | awk -v b="refs/heads/$base_local" '
  /^worktree /{p=substr($0,10)} $0=="branch " b {print p; exit}')"
tmp_wt=""
if [ -z "$base_wt" ]; then
  git rev-parse --verify --quiet "refs/heads/$base_local" >/dev/null || git branch "$base_local" "$base"
  tmp_wt="$(mktemp -d "${TMPDIR:-/tmp}/bbn-merge.XXXXXX")"
  git worktree add --quiet "$tmp_wt" "$base_local" || bbn_die "could not check out $base_local" 3
  base_wt="$tmp_wt"
fi
cleanup_tmp() { [ -n "$tmp_wt" ] && git worktree remove "$tmp_wt" >/dev/null 2>&1; }

bbn_is_clean "$base_wt" || { cleanup_tmp; bbn_die "$base_wt has uncommitted changes" 3; }
if [ "$base" != "$base_local" ]; then
  git -C "$base_wt" merge --quiet --ff-only "$base" 2>/dev/null \
    || { cleanup_tmp; bbn_die "local $base_local has diverged from $base; sync it first (no force)" 3; }
fi
if ! git -C "$base_wt" merge --no-ff --no-edit -m "Merge $branch (bbn gate + review passed)" "$branch"; then
  git -C "$base_wt" merge --abort >/dev/null 2>&1
  cleanup_tmp
  bbn_die "merge conflict on $base_local; aborted. Hand to codex, then /bbn-review again." 4
fi
cleanup_tmp
bbn_ledger merge result=merged "base=$base_local"
bbn_log "merged $branch into local $base_local at $(git rev-parse --short "refs/heads/$base_local")"
bbn_log "not pushed. To publish: git push origin $base_local (never --force)"
bbn_log "afterwards: /bbn-cleanup to remove the merged worktree"
