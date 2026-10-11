#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Create an BBN feature worktree next to the repo, with isolation:
# deterministic dev port, .env.worktree (copied from .env if present), .bbn/ownership.json.
# usage: worktree-new.sh <feature-slug> [--base <ref>]
set -euo pipefail
BBN_TAG=bbn-worktree
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/bbn-common.sh"

slug="${1:-}"; shift || true
BASE_ARG=""
while [ $# -gt 0 ]; do case "$1" in --base) bbn_need_val "$@"; BASE_ARG="$2"; shift 2 ;; *) bbn_die "unknown arg: $1" 2 ;; esac; done
case "$slug" in
  ""|-*) echo "usage: worktree-new.sh <feature-slug> [--base <ref>]" >&2; exit 2 ;;
esac
echo "$slug" | grep -Eq '^[a-z0-9][a-z0-9._-]{0,59}$' || bbn_die "slug must be lowercase letters, digits, . _ - (max 60)" 2

bbn_require_repo
cfg="$HERE/../bbn.config.json"
cfg_int() { sed -n "s/.*\"$1\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$cfg" 2>/dev/null | head -n 1; }
max_wt="${BBN_MAX_WORKTREES:-$(cfg_int maxParallelWorktrees)}"; max_wt="${max_wt:-6}"
port_base="${BBN_PORT_BASE:-$(cfg_int portBase)}"; port_base="${port_base:-3100}"
port_range="$(cfg_int portRange)"; port_range="${port_range:-800}"

current=$(( $(git worktree list --porcelain | grep -c '^worktree ') - 1 ))
[ "$current" -lt "$max_wt" ] || bbn_die "budget: $current feature worktrees already (maxParallelWorktrees=$max_wt). Merge or /bbn-cleanup first." 3

repo_root="$(git rev-parse --show-toplevel)"
main_root="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"
branch="feature/$slug"
dest="$(dirname "$main_root")/$(basename "$main_root")-$slug"
[ -e "$dest" ] && bbn_die "$dest already exists" 3
git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null && bbn_die "branch $branch already exists" 3

git fetch --quiet origin 2>/dev/null || true
start="$(bbn_pick_base "$BASE_ARG")" || exit
# --no-track: a feature branch must not get origin/<base> as its upstream
git worktree add --quiet --no-track -b "$branch" "$dest" "$start"

hash_n="$(printf '%s' "$slug" | cksum | awk '{print $1}')"
port=$(( port_base + hash_n % port_range ))

# Keep BBN files out of git status in every worktree (shared info/exclude).
excl="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || (cd "$(git rev-parse --git-common-dir)" && pwd))/info/exclude"
mkdir -p "$(dirname "$excl")"; touch "$excl"
for pat in .env.worktree .bbn/; do grep -qxF "$pat" "$excl" || echo "$pat" >> "$excl"; done

mkdir -p "$dest/.bbn"
env_note="none (no .env in $repo_root)"
if [ -f "$repo_root/.env" ]; then cp "$repo_root/.env" "$dest/.env.worktree"; env_note="copied from .env"; else : > "$dest/.env.worktree"; fi
{
  echo ""
  echo "# --- bbn worktree isolation ($slug) ---"
  echo "BBN_WORKTREE=1"
  echo "BBN_FEATURE_SLUG=$slug"
  echo "BBN_DEV_PORT=$port"
  echo "PORT=$port"
} >> "$dest/.env.worktree"

cat > "$dest/.bbn/ownership.json" <<JSON
{
  "feature": "$slug",
  "branch": "$branch",
  "base": "$start",
  "devPort": $port,
  "dbBranch": "wt-$slug",
  "paths": [],
  "notes": "List the paths this stream may change. /bbn-status reports overlaps between branches."
}
JSON

bbn_ledger worktree.create "feature=$slug" "port=$port" "start=$start"
bbn_log "worktree=$dest"
bbn_log "branch=$branch start=$start"
bbn_log "devPort=$port env=.env.worktree ($env_note)"
bbn_log "next: fill .bbn/ownership.json paths; use DB branch wt-$slug; never run migrations on a shared writable DB"
