#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Hand a BBN run to herdr so it outlives this terminal/app and keeps the Mac awake until it settles.
# usage: bbn-bg.sh "<self-contained goal>" [-- <extra claude args>]
# Opens a herdr workspace in the main checkout, starts a bbn-orchestrator hub there, and holds
# `caffeinate -i -s` in a side pane until the hub is done or waits on the user. Exit 3: herdr missing.
set -euo pipefail
BBN_TAG=bbn-bg
. "$(cd "$(dirname "$0")" && pwd)/lib/bbn-common.sh"

goal="${1:-}"
case "$goal" in ''|-h|--help) sed -n '3,6p' "$0" >&2; [ -n "$goal" ] && exit 0; exit 2 ;; esac
shift
[ "${1:-}" = "--" ] && shift
bbn_require_repo
command -v herdr >/dev/null 2>&1 || bbn_die "herdr not on PATH: BBN runs its team on herdr only (https://herdr.dev)" 3
# No extra claude args: the hub gets team.claudeArgs (e.g. --permission-mode auto) so it does not stop at every command.
if [ $# -eq 0 ]; then while IFS= read -r a; do set -- "$@" "$a"; done < <(bbn_cfg_list team.claudeArgs); fi

# The main checkout, never a stream worktree: the hub ticks from there.
repo="$(git worktree list --porcelain | awk '/^worktree /&&!s{print substr($0,10); s=1}')"
slug="$(basename "$repo" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | cut -c1-20)"
name="bbn-${slug%-}-$(date +%H%M%S)"

goal_file="$(bbn_state_dir)/$name-$(date +%Y%m%d).goal"
# noclobber: a second launch in the same second must not swap the first hub's goal.
(set -C; printf '%s\n' "$goal" > "$goal_file") 2>/dev/null || bbn_die "another launch just used $name: retry in a second"

pane="$(herdr workspace create --cwd "$repo" --label "$name" --no-focus </dev/null | bbn_jget result.root_pane.pane_id)" \
  || bbn_die "herdr workspace create failed (is the herdr server running? herdr status)"
# A fresh pane's shell is still starting (agent_pane_busy): retry for ~30 s. Blocked at startup
# (e.g. the folder-trust dialog) fails: answer it in the herdr TUI and run again.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  err="$(herdr agent start "$name" --kind claude --pane "$pane" --timeout 120000 -- \
    --agent bbnw:bbn-orchestrator "$@" 2>&1 </dev/null >/dev/null)" && break
  case "$err" in *agent_pane_busy*) sleep 2 ;; *) break ;; esac
done
[ -z "$err" ] || bbn_die "hub did not start in $pane ($err): open herdr, check workspace $name"

side="$(herdr pane split "$pane" --direction down --cwd "$repo" --no-focus </dev/null | bbn_jget result.pane.pane_id)"
q() { printf '%q' "$1"; }
# A one-line pointer, not the goal itself: a long multi-line paste can stall Claude's input
# (agent_prompt_stalled, text left unsubmitted). Re-arm caffeinate each time the hub works again
# (after the user answers it); ends when the hub exits.
n="$(q "$name")"
herdr pane run "$side" "caffeinate -i -s herdr agent prompt $n $(q "Your goal is in $goal_file: read that whole file and follow it.") --wait; while herdr agent wait $n --until working >/dev/null; do caffeinate -i -s herdr agent wait $n >/dev/null; done" </dev/null >/dev/null
picked() { herdr agent wait "$name" --until working --until blocked --until "done" --timeout "$1" </dev/null >/dev/null; }
# Still idle after the prompt = it sits unsubmitted in the hub's input box (agent_prompt_stalled): press Enter once.
# Only when idle: Enter on a question or approval would answer it.
idle() { [ "$(herdr agent get "$name" </dev/null | bbn_jget result.agent.agent_status)" = idle ]; }
picked 30000 || { idle && herdr agent send-keys "$name" enter </dev/null >/dev/null 2>&1 && picked 60000; } \
  || bbn_die "hub $name did not pick up the goal: see the side pane $side in herdr"

state="$(herdr agent get "$name" </dev/null | bbn_jget result.agent.agent_status)" || state=unknown
bbn_log "hub $name is $state in herdr ($pane); caffeinate holds sleep off while it works"
[ "$state" = blocked ] && bbn_warn "hub $name is waiting on you: answer it in herdr (workspace $name)"
bbn_log "watch: herdr agent read $name --source recent-unwrapped --lines 80 | take over: herdr (workspace $name)"
pmset -g 2>/dev/null | grep -q 'SleepDisabled[[:space:]]*1' \
  || bbn_log "closing the lid still sleeps the Mac (run pauses, resumes on wake); to run lid-closed: sudo pmset -a disablesleep 1"
