#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN agent team on herdr: each teammate is a live CLI in its own tab of the hub's herdr workspace.
# usage: bbn-team.sh ask <name> <role> <dir> <brief-file|->   start the teammate if needed, hand it the brief, wait, print its report
#        bbn-team.sh wait <name>                              after exit 4, once the user answered it in herdr: send the brief if it never went out, wait, report
#        bbn-team.sh stop <name>|--all                        close the teammate's tab and forget it
# Roles: claude-code, bbn-reviewer (Claude Code), codex (Codex CLI), hermes (Hermes, profile team.hermesProfile).
# Claude Code and Codex stay open between asks (same name = same context); Hermes runs one turn per ask in its own session.
# Exit: 0 report printed, 1 failed or no report, 2 usage, 3 not inside herdr or the role's CLI/profile missing, 4 waits on the user in herdr.
set -euo pipefail
BBN_TAG=bbn-team
HERE="$(cd "$(dirname "$0")" && pwd)"; R="$(cd "$HERE/.." && pwd)"
. "$HERE/lib/bbn-common.sh"

usage() { sed -n '4,6p' "$0" >&2; exit 2; }
q() { printf '%q' "$1"; }
valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || bbn_die "name '$1' must match [a-z][a-z0-9_-]{0,31} (herdr agent name)" 2; }

cmd="${1:-}"; shift || true
case "$cmd" in ask|wait|stop) ;; *) usage ;; esac
bbn_require_repo
[ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_WORKSPACE_ID:-}" ] \
  || bbn_die "not inside a herdr pane: start the hub with bbn-bg.sh (BBN runs its team on herdr only)" 3
team="$(bbn_common_dir)/team"; mkdir -p "$team"

# One ask/wait per teammate at a time (a dead holder's lock is taken over); keep the Mac awake while we wait.
claim() {
  local l="$team/$1.lock"
  if ! mkdir "$l" 2>/dev/null; then
    kill -0 "$(cat "$l/pid" 2>/dev/null)" 2>/dev/null && bbn_die "$1 is busy with another ask (pid $(cat "$l/pid"))" 1
    rm -rf "$l"; mkdir "$l" 2>/dev/null || bbn_die "$1: another ask just took it" 1
  fi
  echo $$ > "$l/pid"
  trap 'rm -rf "$team/'"$1"'.lock"' EXIT
  if command -v caffeinate >/dev/null 2>&1; then caffeinate -i -s -w $$ >/dev/null 2>&1 & fi
}

waits_on_user() {
  bbn_ledger agent "role=$(cat "$team/$1.role")" "name=$1" "status=partial"
  bbn_die "$1 waits on you in herdr (tab $1: approval, folder trust or sign-in): answer it there, then: bbn-team.sh wait $1" 4
}

# Print the report and log the run. $2 = 0 when the CLI succeeded; the rest = herdr read command when no report was written.
finish() {
  local name="$1" ok="$2" st=ok rc=0; shift 2
  if [ -s "$team/$name.report.md" ]; then cat "$team/$name.report.md"
  else bbn_warn "$name wrote no report (asked a question or stopped early); its last output:"; "$@" </dev/null || true; ok=1; fi
  [ "$ok" = 0 ] || { st=failed; rc=1; }
  bbn_ledger agent "role=$(cat "$team/$name.role")" "name=$name" "status=$st" "seconds=$(( $(date +%s) - $(cat "$team/$name.started") ))"
  return "$rc"
}

# Claude Code / Codex: hand the saved brief to the live teammate and wait until it settles.
submit() {
  local err
  err="$(herdr agent prompt "$1" "Read $team/$1.brief.md and follow it." --wait 2>&1 </dev/null >/dev/null)" || case "$err" in
    *agent_blocked*|*agent_not_ready*) waits_on_user "$1" ;;
    # Stalled while still idle = the text sits unsubmitted in the input box: press Enter once. Any other state
    # (a question or approval on screen, or the turn already ran) must not get a blind Enter.
    *agent_prompt_stalled*) case "$(status "$1")" in
        idle) herdr agent send-keys "$1" enter </dev/null >/dev/null 2>&1 \
          || bbn_die "$1: prompt stalled and Enter failed; look at tab $1 in herdr before asking again" 1 ;;
        blocked) waits_on_user "$1" ;;
      esac ;;
    *) bbn_die "$1: prompt not confirmed ($err); look at tab $1 in herdr before asking again" 1 ;;
  esac
  touch "$team/$1.sent"
}

status() { herdr agent get "$1" </dev/null | bbn_jget result.agent.agent_status || echo gone; }

# True while the teammate's CLI still runs a Claude Code Bash command (its wrapper sources shell-snapshots),
# e.g. a backgrounded bbn-codex.sh review: Claude ends its turn then and resumes when the command exits.
running_cmd() {
  local root
  root="$(herdr pane process-info --pane "$(cat "$team/$1.pane")" </dev/null | bbn_jget result.process_info.shell_pid)" || return 1
  ps -axo pid=,ppid=,command= | awk -v r="$root" '
    { pp[$1] = $2; c = $0; sub(/^ *[0-9]+ +[0-9]+ +/, "", c); cmd[$1] = c }
    END { for (p in cmd) if (cmd[p] ~ /shell-snapshots/) for (a = pp[p]; a > 1; a = pp[a]) if (a == r) exit 0; exit 1 }'
}

# Settled is not finished: wait for the report while the teammate works or runs a command, and give up after
# 30 s with neither. A running command stops counting after codex.timeoutSec + 10 min, so a background server
# left by an earlier ask cannot hold the wait open forever.
settle() {
  local st quiet=0 cap
  cap="$(bbn_cfg_list codex.timeoutSec)"; cap=$(( $(cat "$team/$1.started") + ${cap:-3600} + 600 ))
  while :; do
    [ -s "$team/$1.report.md" ] && break
    st="$(status "$1")"
    case "$st" in
      blocked) waits_on_user "$1" ;;
      gone) [ -s "$team/$1.report.md" ] && break
        bbn_die "$1 is gone (exited or its tab closed): ask again to start a new one" 1 ;;
    esac
    if [ "$st" = working ] || { [ "$(date +%s)" -lt "$cap" ] && running_cmd "$1"; }; then quiet=0
    else quiet=$((quiet + 1)); [ "$quiet" -ge 6 ] && break; fi
    sleep 5
  done
  finish "$1" 0 herdr agent read "$1" --source recent-unwrapped --lines 120
}

# Hermes: one turn per ask; the shell writes the exit code to $name.rc when the turn ends.
hermes_settle() {
  local pane rc
  pane="$(cat "$team/$1.pane")"
  while [ ! -s "$team/$1.rc" ]; do
    herdr pane get "$pane" </dev/null >/dev/null 2>&1 || bbn_die "$1: its herdr tab was closed mid-run" 1
    sleep 3
  done
  rc="$(cat "$team/$1.rc")"; [ "$rc" = 0 ] || bbn_warn "$1: hermes exited $rc"
  finish "$1" "$rc" herdr pane read "$pane" --source recent-unwrapped --lines 120
}

open_tab() {  # $1 name, $2 dir -> prints the new pane id
  local j
  j="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$2" --label "$1" --no-focus </dev/null)" \
    || bbn_die "herdr tab create failed (herdr status)" 1
  printf '%s' "$j" | bbn_jget result.tab.tab_id > "$team/$1.tab"
  printf '%s\n' "$2" > "$team/$1.dir"
  printf '%s' "$j" | bbn_jget result.root_pane.pane_id | tee "$team/$1.pane"
}

case "$cmd" in
stop)
  [ $# -eq 1 ] || usage
  if [ "$1" = --all ]; then set -- "$team"/*.tab; else valid_name "$1"; set -- "$team/$1.tab"; fi
  rc=0
  for t in "$@"; do
    [ -f "$t" ] || continue
    n="$(basename "$t" .tab)"; id="$(cat "$t")"
    if herdr tab close "$id" </dev/null >/dev/null 2>&1 || ! herdr tab get "$id" </dev/null >/dev/null 2>&1; then
      rm -rf "$team/$n".*; bbn_log "stopped $n"
    else bbn_warn "could not close tab $id ($n): close it in herdr, then stop again"; rc=1; fi
  done
  exit "$rc" ;;

wait)
  [ $# -eq 1 ] || usage; valid_name "$1"
  [ -f "$team/$1.role" ] || bbn_die "no teammate $1 (ask first)" 1
  claim "$1"
  if [ "$(cat "$team/$1.role")" = hermes ]; then hermes_settle "$1"
  elif [ -f "$team/$1.sent" ]; then herdr agent wait "$1" </dev/null >/dev/null || true; settle "$1"
  else submit "$1"; settle "$1"; fi ;;

ask)
  [ $# -eq 4 ] || usage
  name="$1"; role="$2"; dir="$3"; src="$4"; valid_name "$name"
  case "$role" in
    claude-code|bbn-reviewer) kind=claude ;;
    codex|hermes) kind="$role" ;;
    *) bbn_die "unknown role '$role' (claude-code, codex, hermes, bbn-reviewer)" 2 ;;
  esac
  [ -d "$dir" ] || bbn_die "no directory $dir" 2
  [ "$src" = - ] || [ -r "$src" ] || bbn_die "cannot read brief $src" 2
  dir="$(cd "$dir" && pwd)"
  command -v "$kind" >/dev/null 2>&1 || bbn_die "$kind CLI not on PATH: give build/fix work to claude-code" 3
  # A known teammate must still work where this ask points; a new name must not be a live agent of another run.
  [ ! -f "$team/$name.dir" ] || [ "$(cat "$team/$name.dir")" = "$dir" ] \
    || bbn_die "$name works in $(cat "$team/$name.dir"), not $dir: stop it or use another name" 2
  live="$(herdr agent get "$name" </dev/null 2>/dev/null | bbn_jget result.agent.pane_id)" || live=""
  [ -z "$live" ] || [ "$live" = "$(cat "$team/$name.pane" 2>/dev/null)" ] \
    || bbn_die "herdr name $name belongs to another teammate (another run?): use another name" 2
  claim "$name"
  brief="$team/$name.brief.md"
  { printf '# BBN task for teammate %s (role %s)\n\n' "$name" "$role"
    # shellcheck disable=SC2016  # the literal ${CLAUDE_PLUGIN_ROOT} as written in the role file
    printf 'Plugin root R = %s. Read your role instructions in R/agents/%s.md first and follow them; `${CLAUDE_PLUGIN_ROOT}` there means R.\nWork in %s only.\n\n' "$R" "$role" "$dir"
    if [ "$src" = - ]; then cat; else cat -- "$src"; fi
    printf '\n\nLast step: write your report to %s: what you did, every acceptance command with its exit code, and the commit sha (reviewers: the VERDICT or PLAN line). If you stop early or need an answer, say why there. Always write that file, and write it last, then stop.\n' "$team/$name.report.md"
  } > "$brief"
  rm -f "$team/$name.report.md" "$team/$name.rc" "$team/$name.sent"
  printf '%s\n' "$role" > "$team/$name.role"; date +%s > "$team/$name.started"

  if [ "$kind" = hermes ]; then
    prof="$(bbn_cfg_list team.hermesProfile)"; prof="${prof:-bbn}"
    hermes profile show "$prof" </dev/null >/dev/null 2>&1 \
      || bbn_die "hermes profile '$prof' missing (BBN's own clean memory): hermes profile create $prof --clone-from default --no-alias" 3
    pane="$(cat "$team/$name.pane" 2>/dev/null)" && herdr pane get "$pane" </dev/null >/dev/null 2>&1 || pane="$(open_tab "$name" "$dir")"
    # Session title unique to this teammate's lifetime: a name reused by another repo or run never resumes old work.
    [ -s "$team/$name.session" ] || printf '%s-%s\n' "$name" "$(date +%s)" > "$team/$name.session"
    line="hermes -p $(q "$prof") chat --query-file $(q "$brief") --oneshot --in $(q "$dir") -c $(q "$(cat "$team/$name.session")") --create-if-missing"
    while IFS= read -r a; do line="$line $(q "$a")"; done < <(bbn_cfg_list team.hermesArgs)
    herdr pane run "$pane" "$line; echo \$? > $(q "$team/$name.rc")" </dev/null >/dev/null \
      || bbn_die "could not run hermes in $pane (is the tab at its shell prompt?)" 1
    touch "$team/$name.sent"
    hermes_settle "$name"; exit
  fi

  if [ -z "$live" ]; then  # a live teammate keeps its context between asks
    [ -f "$team/$name.tab" ] && { herdr tab close "$(cat "$team/$name.tab")" </dev/null >/dev/null 2>&1 || true; }
    pane="$(open_tab "$name" "$dir")"
    if [ "$kind" = claude ]; then args=(--agent "bbnw:$role")
    else
      model="${BBN_CODEX_MODEL:-$(bbn_cfg_list codex.model)}"; effort="${BBN_CODEX_EFFORT:-$(bbn_cfg_list codex.reasoningEffort)}"
      args=(--add-dir "$team"); [ -n "$model" ] && args+=(-m "$model"); [ -n "$effort" ] && args+=(-c "model_reasoning_effort=$effort")
    fi
    while IFS= read -r a; do args+=("$a"); done < <(bbn_cfg_list "team.${kind}Args")
    # A fresh tab's shell is still starting (agent_pane_busy): retry for ~30 s.
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      err="$(herdr agent start "$name" --kind "$kind" --pane "$pane" --timeout 120000 -- "${args[@]}" 2>&1 </dev/null >/dev/null)" && break
      case "$err" in *agent_pane_busy*) sleep 2 ;; *) break ;; esac
    done
    case "$err" in
      '') ;;
      *agent_not_ready*) waits_on_user "$name" ;;
      *) bbn_die "$name did not start in $pane: $err" 1 ;;
    esac
  fi
  submit "$name"; settle "$name" ;;
esac
