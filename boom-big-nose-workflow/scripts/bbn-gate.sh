#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN review gate: lint + typecheck + test. Exit 0 pass, 1 fail, 2 nothing ran.
# Override with BBN_GATE_CMD="..." or an executable .bbn/gate.sh at the repo root.
# Records the result for the current HEAD in <git-dir>/bbn/gate.json unless --no-record.
# Each step is limited to BBN_GATE_TIMEOUT seconds (default reviewGate.stepTimeoutSec, 1800); a timeout fails the step.
set -uo pipefail
BBN_TAG=bbn-gate
. "$(cd "$(dirname "$0")" && pwd)/lib/bbn-common.sh"

RECORD=1
for a in "$@"; do
  case "$a" in
    --no-record) RECORD=0 ;;
    -h|--help) echo "usage: bbn-gate.sh [--no-record]"; exit 0 ;;
    *) bbn_die "unknown arg: $a" 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root" || exit 1
export CI="${CI:-1}"   # keep test runners out of watch mode

failures=0; ran=0; steps=""
STEP_TIMEOUT="${BBN_GATE_TIMEOUT:-$(bbn_cfg_int stepTimeoutSec 1800)}"
start_s="$(date +%s)"
run_step() {
  local name="$1"; shift
  bbn_log "RUN  $name: $*"
  ran=$((ran + 1))
  bbn_run_timeout "$STEP_TIMEOUT" "$@"; local rc=$?
  if [ "$rc" -eq 0 ]; then bbn_log "PASS $name"; steps="$steps $name:pass"
  elif [ "$rc" -eq 124 ]; then bbn_log "FAIL $name (TIMEOUT after ${STEP_TIMEOUT}s)"; failures=$((failures + 1)); steps="$steps $name:timeout"
  else bbn_log "FAIL $name (exit $rc)"; failures=$((failures + 1)); steps="$steps $name:fail"; fi
}
has_script() {
  if command -v node >/dev/null 2>&1; then
    node -e "const s=(require('./package.json').scripts)||{};process.exit(s[process.argv[1]]?0:1)" "$1" 2>/dev/null
  else
    grep -q "\"$1\"[[:space:]]*:" package.json
  fi
}
run_js() {
  local pm="$1"
  has_script lint && run_step lint "$pm" run lint
  if has_script typecheck; then run_step typecheck "$pm" run typecheck
  elif has_script type-check; then run_step typecheck "$pm" run type-check
  elif [ -f tsconfig.json ] && [ -x node_modules/.bin/tsc ]; then run_step typecheck node_modules/.bin/tsc --noEmit
  fi
  has_script test && run_step test "$pm" run test
  return 0
}

if [ -n "${BBN_GATE_CMD:-}" ]; then
  run_step custom bash -c "$BBN_GATE_CMD"
elif [ -x .bbn/gate.sh ]; then
  run_step custom ./.bbn/gate.sh
elif [ -f pubspec.yaml ]; then
  if command -v flutter >/dev/null 2>&1; then
    run_step analyze flutter analyze
    [ -d test ] && run_step test flutter test
  else
    bbn_warn "pubspec.yaml found but flutter is not installed"; failures=$((failures + 1)); ran=$((ran + 1))
  fi
elif [ -f package.json ]; then
  if   [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then run_js pnpm
  elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then run_js yarn
  elif { [ -f bun.lockb ] || [ -f bun.lock ]; } && command -v bun >/dev/null 2>&1; then run_js bun
  elif command -v npm >/dev/null 2>&1; then run_js npm
  else bbn_warn "package.json found but no npm/pnpm/yarn/bun"; failures=$((failures + 1)); ran=$((ran + 1)); fi
elif [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  run_step check cargo check --all-targets; run_step test cargo test
elif [ -f go.mod ] && command -v go >/dev/null 2>&1; then
  run_step vet go vet ./...; run_step test go test ./...
elif [ -f pyproject.toml ] || [ -f pytest.ini ]; then
  command -v pytest >/dev/null 2>&1 && run_step test pytest
fi

if [ "$ran" -eq 0 ]; then result=empty; code=2
elif [ "$failures" -gt 0 ]; then result=fail; code=1
else result=pass; code=0; fi

if [ "$RECORD" -eq 1 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  sd="$(bbn_state_dir)"
  cat > "$sd/gate.json" <<JSON
{
  "result": "$result",
  "head": "$(git rev-parse HEAD 2>/dev/null)",
  "at": "$(bbn_now)",
  "steps": "$(bbn_json_escape "${steps# }")"
}
JSON
fi

if [ "$RECORD" -eq 1 ]; then bbn_ledger gate "result=$result" "steps=${steps# }" "seconds=$(( $(date +%s) - start_s ))"; fi

case "$result" in
  pass)  bbn_log "GATE PASSED ($ran step(s))" ;;
  fail)  bbn_log "GATE FAILED ($failures of $ran step(s))" ;;
  empty) bbn_warn "no checks found; set BBN_GATE_CMD or add .bbn/gate.sh" ;;
esac
exit "$code"
