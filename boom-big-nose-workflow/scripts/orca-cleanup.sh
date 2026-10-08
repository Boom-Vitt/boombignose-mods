#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Orca cleanup: remove worktrees whose branch is merged into base. Dry-run by default.
#   --apply             actually remove (clean worktrees only; never --force)
#   --delete-branches   also delete merged local branches with git branch -d (never -D, never remote)
#   --include-unmerged  also remove clean worktrees of UNMERGED branches (branch itself is kept)
#   --base <ref>
set -uo pipefail
ORCA_TAG=orca-cleanup
. "$(cd "$(dirname "$0")" && pwd)/lib/orca-common.sh"
APPLY=0; DELB=0; UNMERGED=0; BASE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;; --delete-branches) DELB=1; shift ;;
    --include-unmerged) UNMERGED=1; shift ;; --base) BASE_ARG="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;; *) orca_die "unknown arg: $1" 2 ;;
  esac
done
orca_require_repo
base="$(orca_pick_base "$BASE_ARG")"; base_local="${base#origin/}"
main_wt="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"
here="$(git rev-parse --show-toplevel)"
orca_log "base=$base mode=$([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN)"

is_merged() {
  git merge-base --is-ancestor "$1" "$base" 2>/dev/null && return 0
  git rev-parse --verify --quiet "refs/heads/$base_local" >/dev/null && \
    git merge-base --is-ancestor "$1" "refs/heads/$base_local" 2>/dev/null
}

list="$(git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch /{sub("refs/heads/","",$2); print p "\t" $2}')"
removed=0
while IFS="$(printf '\t')" read -r wt br; do
  [ -n "$wt" ] || continue
  [ "$wt" = "$main_wt" ] && continue
  orca_protected_branch "$br" && continue
  if [ "$wt" = "$here" ]; then orca_log "skip $br: current worktree ($wt)"; continue; fi
  if [ ! -d "$wt" ]; then orca_log "stale entry $wt (prune)"; continue; fi
  if ! orca_is_clean "$wt" || [ -n "$(git -C "$wt" ls-files --others --exclude-standard)" ]; then
    orca_log "keep $br: uncommitted or untracked files in $wt"; continue
  fi
  if is_merged "$br"; then state=merged
  elif [ $UNMERGED -eq 1 ]; then state=unmerged
  else orca_log "keep $br: not merged into $base"; continue; fi
  if [ $APPLY -eq 0 ]; then
    orca_log "would remove worktree $wt ($br, $state)$([ "$DELB" -eq 1 ] && [ "$state" = merged ] && echo ' + delete branch')"
    continue
  fi
  if git worktree remove "$wt"; then
    orca_log "removed worktree $wt ($br, $state)"; removed=$((removed + 1))
    if [ "$DELB" -eq 1 ] && [ "$state" = merged ]; then
      if git branch -d "$br" >/dev/null 2>&1; then orca_log "deleted local branch $br"
      else orca_warn "kept branch $br: git branch -d refused (it tracks an upstream it is not merged into; check git branch -vv)"; fi
    fi
  else
    orca_warn "could not remove $wt; left as is"
  fi
done <<LIST
$list
LIST

if [ $APPLY -eq 1 ]; then git worktree prune; orca_ledger cleanup "removed=$removed"; orca_log "done: $removed worktree(s) removed"
else git worktree prune --dry-run -v 2>&1 | sed 's/^/[orca-cleanup] prune: /'; orca_log "dry-run only; re-run with --apply"; fi
