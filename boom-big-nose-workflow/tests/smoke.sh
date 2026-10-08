#!/usr/bin/env bash
# End-to-end dry run of the Orca flow in a throwaway repo (no network, nothing outside the temp dir):
# plan -> checkpoint -> 2 worktrees -> simulated planner/coder output -> gate -> review -> queue ->
# merge in plan order -> report -> cleanup.
# usage: bash tests/smoke.sh
set -u
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
command -v node >/dev/null 2>&1 || { echo "skip: node not installed"; exit 0; }
T="$(mktemp -d "${TMPDIR:-/tmp}/orca-smoke.XXXXXX")"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" ORCA_DOCTOR_OFFLINE=1 TMPDIR="$T" ORCA_GATE_CMD="test -f done.txt"
unset ORCA_BASE CLAUDE_PLUGIN_ROOT 2>/dev/null || true
git config --global user.name "orca smoke"; git config --global user.email "orca@test.invalid"; git config --global init.defaultBranch main

pass=0; fail=0
step() { local name="$1" want="$2"; shift 2; local out; out="$("$@" 2>&1)"; local got=$?
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); echo "ok   $name"; else fail=$((fail + 1)); echo "FAIL $name (exit $got, want $want)"; echo "$out" | sed 's/^/     /'; fi; }
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

git init -q --bare "$T/origin.git"; git clone -q "$T/origin.git" "$T/shop" 2>/dev/null; cd "$T/shop" || exit 1
mkdir -p src/api src/ui; echo api > src/api/index.txt; echo ui > src/ui/index.txt; touch done.txt
git add -A; git commit -qm init; git push -q origin main

# 1. planner output (what grok-build returns), saved by Orca
mkdir -p .orca
cat > .orca/plan.json <<'JSON'
{ "version": 1, "title": "checkout", "status": "draft",
  "goal": "add a checkout API and its UI",
  "streams": [
    { "slug": "checkout-ui", "role": "claude-code", "paths": ["src/ui/"], "dependsOn": ["checkout-api"], "acceptance": ["test -f src/ui/checkout.txt"] },
    { "slug": "checkout-api", "role": "claude-code", "paths": ["src/api/"], "acceptance": ["test -f src/api/checkout.txt"] } ] }
JSON
step "plan check" 0 node "$S/orca-plan.mjs" check
step "apply refused before checkpoint" 3 node "$S/orca-plan.mjs" apply --apply
step "plan accept (checkpoint)" 0 node "$S/orca-plan.mjs" accept
step "apply dry-run" 0 node "$S/orca-plan.mjs" apply
check "dry-run created nothing" '[ "$(git worktree list | wc -l | tr -d " ")" = 1 ]'
step "apply --apply creates worktrees" 0 node "$S/orca-plan.mjs" apply --apply
API="$T/shop-checkout-api"; UI="$T/shop-checkout-ui"
check "two worktrees exist" '[ -d "$API" ] && [ -d "$UI" ]'
check "ownership carries plan paths + deps" 'grep -q "\"src/ui/\"" "$UI/.orca/ownership.json" && grep -q checkout-api "$UI/.orca/ownership.json"'

# 2. coder output (what claude-code commits in each worktree)
(cd "$API" && echo "POST /checkout" > src/api/checkout.txt && git add -A && git commit -qm "api: checkout")
(cd "$UI" && echo "checkout button" > src/ui/checkout.txt && git add -A && git commit -qm "ui: checkout")
"$S/orca-ledger.sh" agent claude-code --turns 9 >/dev/null; "$S/orca-ledger.sh" agent claude-code --turns 14 >/dev/null

# 3. gate + review for both
for W in "$API" "$UI"; do
  (cd "$W" && "$S/orca-gate.sh" >/dev/null 2>&1 && "$S/orca-review-record.sh" APPROVE --note smoke >/dev/null)
  "$S/orca-ledger.sh" agent orca-reviewer --turns 5 >/dev/null
done
check "both gated + approved" '[ "$(grep -c "\"event\":\"review\"" "$(git rev-parse --path-format=absolute --git-common-dir)/orca/runs.jsonl")" = 2 ]'

# 4. queue respects plan order
out="$(node "$S/orca-queue.mjs" 2>&1)"
check "queue: api before ui, both ready" '[ "$(echo "$out" | awk "\$1==\"1\"{print \$2}")" = feature/checkout-api ] && echo "$out" | grep -q "^2  feature/checkout-ui *yes"'

# 5. merge out of order is refused, in order succeeds
step "merge ui first refused (plan order)" 3 sh -c "cd '$UI' && '$S/orca-merge.sh' --apply"
step "merge api" 0 sh -c "cd '$API' && '$S/orca-merge.sh' --apply"
step "merge ui (rebases onto api)" 0 sh -c "cd '$UI' && '$S/orca-merge.sh' --apply"
check "main has both features" '[ -f src/api/checkout.txt ] && [ -f src/ui/checkout.txt ]'
check "nothing pushed" '[ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$(git rev-parse origin/main)" ] && [ "$(git rev-parse origin/main)" != "$(git rev-parse main)" ]'

# 6. report + cleanup
out="$(node "$S/orca-report.mjs" 2>&1)"
check "report: 2 merges, agent turns" 'echo "$out" | grep -q "merges: .*merged 2" && echo "$out" | grep -q "claude-code .*runs 2, turns 23"'
step "cleanup --apply --delete-branches" 0 "$S/orca-cleanup.sh" --apply --delete-branches --base main
check "worktrees and merged branches gone" '[ ! -d "$API" ] && [ ! -d "$UI" ] && ! git rev-parse --verify --quiet refs/heads/feature/checkout-ui >/dev/null'

echo "---"; echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
