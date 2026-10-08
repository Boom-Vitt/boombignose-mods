#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Create an Orca feature worktree next to the repo, with isolation:
# deterministic dev port, .env.worktree (copied from .env if present), .orca/ownership.json.
# usage: worktree-new.sh <feature-slug> [--base <ref>]
set -euo pipefail
ORCA_TAG=orca-worktree
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/orca-common.sh"

slug="${1:-}"; shift || true
BASE_ARG=""
while [ $# -gt 0 ]; do case "$1" in --base) BASE_ARG="${2:-}"; shift 2 ;; *) orca_die "unknown arg: $1" 2 ;; esac; done
case "$slug" in
  ""|-*) echo "usage: worktree-new.sh <feature-slug> [--base <ref>]" >&2; exit 2 ;;
esac
echo "$slug" | grep -Eq '^[a-z0-9][a-z0-9._-]{0,59}$' || orca_die "slug must be lowercase letters, digits, . _ - (max 60)" 2

orca_require_repo
cfg="$HERE/../orca.config.json"
cfg_int() { sed -n "s/.*\"$1\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$cfg" 2>/dev/null | head -n 1; }
max_wt="${ORCA_MAX_WORKTREES:-$(cfg_int maxParallelWorktrees)}"; max_wt="${max_wt:-6}"
port_base="${ORCA_PORT_BASE:-$(cfg_int portBase)}"; port_base="${port_base:-3100}"
port_range="$(cfg_int portRange)"; port_range="${port_range:-800}"

current=$(( $(git worktree list --porcelain | grep -c '^worktree ') - 1 ))
[ "$current" -lt "$max_wt" ] || orca_die "budget: $current feature worktrees already (maxParallelWorktrees=$max_wt). Merge or /orca-cleanup first." 3

repo_root="$(git rev-parse --show-toplevel)"
main_root="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"
branch="feature/$slug"
dest="$(dirname "$main_root")/$(basename "$main_root")-$slug"
[ -e "$dest" ] && orca_die "$dest already exists" 3
git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null && orca_die "branch $branch already exists" 3

git fetch --quiet origin 2>/dev/null || true
start="$(orca_pick_base "$BASE_ARG")"
# --no-track: a feature branch must not get origin/<base> as its upstream
git worktree add --quiet --no-track -b "$branch" "$dest" "$start"

hash_n="$(printf '%s' "$slug" | cksum | awk '{print $1}')"
port=$(( port_base + hash_n % port_range ))

# Keep Orca files out of git status in every worktree (shared info/exclude).
excl="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || (cd "$(git rev-parse --git-common-dir)" && pwd))/info/exclude"
mkdir -p "$(dirname "$excl")"; touch "$excl"
for pat in .env.worktree .orca/; do grep -qxF "$pat" "$excl" || echo "$pat" >> "$excl"; done

mkdir -p "$dest/.orca"
env_note="none (no .env in $repo_root)"
if [ -f "$repo_root/.env" ]; then cp "$repo_root/.env" "$dest/.env.worktree"; env_note="copied from .env"; else : > "$dest/.env.worktree"; fi
{
  echo ""
  echo "# --- orca worktree isolation ($slug) ---"
  echo "ORCA_WORKTREE=1"
  echo "ORCA_FEATURE_SLUG=$slug"
  echo "ORCA_DEV_PORT=$port"
  echo "PORT=$port"
} >> "$dest/.env.worktree"

cat > "$dest/.orca/ownership.json" <<JSON
{
  "feature": "$slug",
  "branch": "$branch",
  "base": "$start",
  "devPort": $port,
  "dbBranch": "wt-$slug",
  "paths": [],
  "notes": "List the paths this stream may change. /orca-status reports overlaps between branches."
}
JSON

orca_ledger worktree.create "feature=$slug" "port=$port" "start=$start"
orca_log "worktree=$dest"
orca_log "branch=$branch start=$start"
orca_log "devPort=$port env=.env.worktree ($env_note)"
orca_log "next: fill .orca/ownership.json paths; use DB branch wt-$slug; never run migrations on a shared writable DB"
