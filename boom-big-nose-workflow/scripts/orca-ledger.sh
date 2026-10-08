#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Orca run ledger (<common-git-dir>/orca/runs.jsonl). Scripts append gate/review/merge/worktree/cleanup
# events automatically; Orca records each subagent run with:
#   orca-ledger.sh agent <role> --turns N [--status ok|partial|failed] [--note text]
#   orca-ledger.sh tail [N]        print the last N events (default 20)
#   orca-ledger.sh path            print the ledger path
# Exit: 0 ok, 2 usage
set -uo pipefail
ORCA_TAG=orca-ledger
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/orca-common.sh"
orca_require_repo
case "${1:-}" in
  agent)
    role="${2:-}"; shift 2 || true
    [ -f "$HERE/../agents/$role.md" ] || orca_die "unknown role '$role' (see agents/)" 2
    turns=""; status=ok; note=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --turns) turns="${2:-}"; shift 2 ;;
        --status) status="${2:-}"; shift 2 ;;
        --note) note="${2:-}"; shift 2 ;;
        *) orca_die "unknown arg: $1" 2 ;;
      esac
    done
    case "$turns" in ''|*[!0-9]*) orca_die "--turns <integer> required" 2 ;; esac
    case "$status" in ok|partial|failed) ;; *) orca_die "--status must be ok, partial or failed" 2 ;; esac
    orca_ledger agent "role=$role" "turns=$turns" "status=$status" "note=$note"
    orca_log "recorded $role: $turns turns ($status)" ;;
  tail) tail -n "${2:-20}" "$(orca_common_dir)/runs.jsonl" 2>/dev/null || true ;;
  path) printf '%s\n' "$(orca_common_dir)/runs.jsonl" ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
