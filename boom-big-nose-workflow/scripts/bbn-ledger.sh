#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN run ledger (<common-git-dir>/bbn/runs.jsonl). Scripts append gate/review/merge/worktree/cleanup
# events automatically; BBN records each subagent run with:
#   bbn-ledger.sh agent <role> --turns N [--status ok|partial|failed] [--note text]
#   bbn-ledger.sh tail [N]        print the last N events (default 20)
#   bbn-ledger.sh path            print the ledger path
# Exit: 0 ok, 2 usage
set -uo pipefail
BBN_TAG=bbn-ledger
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/bbn-common.sh"
bbn_require_repo
case "${1:-}" in
  agent)
    role="${2:-}"; shift 2 || true
    [ -f "$HERE/../agents/$role.md" ] || bbn_die "unknown role '$role' (see agents/)" 2
    turns=""; status=ok; note=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --turns) bbn_need_val "$@"; turns="$2"; shift 2 ;;
        --status) bbn_need_val "$@"; status="$2"; shift 2 ;;
        --note) bbn_need_val "$@"; note="$2"; shift 2 ;;
        *) bbn_die "unknown arg: $1" 2 ;;
      esac
    done
    case "$turns" in ''|*[!0-9]*) bbn_die "--turns <integer> required" 2 ;; esac
    case "$status" in ok|partial|failed) ;; *) bbn_die "--status must be ok, partial or failed" 2 ;; esac
    bbn_ledger agent "role=$role" "turns=$turns" "status=$status" "note=$note"
    bbn_log "recorded $role: $turns turns ($status)" ;;
  tail) tail -n "${2:-20}" "$(bbn_common_dir)/runs.jsonl" 2>/dev/null || true ;;
  path) printf '%s\n' "$(bbn_common_dir)/runs.jsonl" ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
