#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Run the real Codex CLI inside the current worktree.
# usage: bbn-codex.sh run "<brief>"          Codex edits files; the caller commits.
#        bbn-codex.sh review [--base <ref>]   read-only second opinion, ends with a VERDICT line.
# Model and effort: BBN_CODEX_MODEL / BBN_CODEX_EFFORT, else "codex" in bbn.config.json.
set -euo pipefail
BBN_TAG=bbn-codex
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/bbn-common.sh"

usage() { echo 'usage: bbn-codex.sh run "<brief>" | review [--base <ref>]' >&2; exit 2; }
mode="${1:-}"; shift || true
brief=""; base_arg=""
case "$mode" in
  run) brief="${1:-}"; [ -n "$brief" ] || usage ;;
  review) while [ $# -gt 0 ]; do
      case "$1" in --base) [ -n "${2:-}" ] || usage; base_arg="$2"; shift 2 ;; *) usage ;; esac
    done ;;
  *) usage ;;
esac

bbn_require_repo
command -v codex >/dev/null 2>&1 || bbn_die "codex CLI not on PATH: give this work to claude-code" 3

cfg="$HERE/../bbn.config.json"
model="${BBN_CODEX_MODEL:-$(bbn_json_get "$cfg" model)}"
effort="${BBN_CODEX_EFFORT:-$(bbn_json_get "$cfg" reasoningEffort)}"
limit="$(bbn_cfg_int timeoutSec 3600)"
root="$(git rev-parse --show-toplevel)"

guard="You work inside the git worktree $root only. Do not commit, push, rebase, reset, stash or switch branches; the caller handles git. Never print secrets or the contents of .env files."
if [ "$mode" = run ]; then
  sandbox=workspace-write
  prompt="$guard

$brief"
else
  sandbox=read-only
  base="$(bbn_pick_base "$base_arg")" || exit
  prompt="$guard

Review the changes on this branch against $base (git diff \$(git merge-base $base HEAD) HEAD) for bugs, security issues and missing tests. Do not edit files. List each finding as file:line - problem - fix. End with exactly one line: VERDICT: APPROVE, VERDICT: REQUEST_CHANGES or VERDICT: BLOCK."
fi

sd="$(bbn_state_dir)"
out="$sd/codex-$mode.md"; log="$sd/codex-$mode.log"
rm -f "$out"
args=(exec -C "$root" --skip-git-repo-check -s "$sandbox" -o "$out")
[ -n "$model" ] && args+=(-m "$model")
[ -n "$effort" ] && args+=(-c "model_reasoning_effort=$effort")

bbn_log "codex $mode (${model:-default model}, ${effort:-default effort}, limit ${limit}s)"
start=$(date +%s); rc=0
bbn_run_timeout "$limit" codex "${args[@]}" "$prompt" < /dev/null > "$log" 2>&1 || rc=$?
secs=$(( $(date +%s) - start ))
result=ok; [ "$rc" -eq 0 ] && [ -s "$out" ] || result=fail
bbn_ledger codex "mode=$mode" "result=$result" "seconds=$secs"

if [ "$result" = fail ]; then
  bbn_warn "codex exit $rc after ${secs}s; last log lines:"
  tail -n 20 "$log" >&2
  exit 1
fi
cat "$out"
