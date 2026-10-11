#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Record the bbn-reviewer verdict for the current branch state.
# usage: bbn-review-record.sh APPROVE|REQUEST_CHANGES|BLOCK [--base <ref>] [--note "text"]
set -euo pipefail
BBN_TAG=bbn-review
. "$(cd "$(dirname "$0")" && pwd)/lib/bbn-common.sh"

verdict="${1:-}"; shift || true
case "$verdict" in APPROVE|REQUEST_CHANGES|BLOCK) ;; *)
  echo "usage: bbn-review-record.sh APPROVE|REQUEST_CHANGES|BLOCK [--base <ref>] [--note text]" >&2; exit 2 ;; esac
base_arg=""; note=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) bbn_need_val "$@"; base_arg="$2"; shift 2 ;;
    --note) bbn_need_val "$@"; note="$2"; shift 2 ;;
    *) bbn_die "unknown arg: $1" 2 ;;
  esac
done

bbn_require_repo
bbn_is_clean || bbn_die "uncommitted changes: commit first so the review matches what will merge"
base="$(bbn_pick_base "$base_arg")" || exit
sd="$(bbn_state_dir)"
pid="$(bbn_patch_id "$base")"
cat > "$sd/review.json" <<JSON
{
  "verdict": "$verdict",
  "branch": "$(git rev-parse --abbrev-ref HEAD)",
  "head": "$(git rev-parse HEAD)",
  "base": "$base",
  "patch_id": "$pid",
  "at": "$(bbn_now)",
  "note": "$(bbn_json_escape "$note")"
}
JSON
bbn_ledger review "verdict=$verdict" "head=$(git rev-parse --short HEAD)"
bbn_log "recorded $verdict for $(git rev-parse --short HEAD) (base $base)"
