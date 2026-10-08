#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Record the orca-reviewer verdict for the current branch state.
# usage: orca-review-record.sh APPROVE|REQUEST_CHANGES|BLOCK [--base <ref>] [--note "text"]
set -euo pipefail
ORCA_TAG=orca-review
. "$(cd "$(dirname "$0")" && pwd)/lib/orca-common.sh"

verdict="${1:-}"; shift || true
case "$verdict" in APPROVE|REQUEST_CHANGES|BLOCK) ;; *)
  echo "usage: orca-review-record.sh APPROVE|REQUEST_CHANGES|BLOCK [--base <ref>] [--note text]" >&2; exit 2 ;; esac
base_arg=""; note=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base_arg="${2:-}"; shift 2 ;;
    --note) note="${2:-}"; shift 2 ;;
    *) orca_die "unknown arg: $1" 2 ;;
  esac
done

orca_require_repo
orca_is_clean || orca_die "uncommitted changes: commit first so the review matches what will merge"
base="$(orca_pick_base "$base_arg")"
sd="$(orca_state_dir)"
cat > "$sd/review.json" <<JSON
{
  "verdict": "$verdict",
  "branch": "$(git rev-parse --abbrev-ref HEAD)",
  "head": "$(git rev-parse HEAD)",
  "base": "$base",
  "patch_id": "$(orca_patch_id "$base")",
  "at": "$(orca_now)",
  "note": "$(orca_json_escape "$note")"
}
JSON
orca_ledger review "verdict=$verdict" "head=$(git rev-parse --short HEAD)"
orca_log "recorded $verdict for $(git rev-parse --short HEAD) (base $base)"
