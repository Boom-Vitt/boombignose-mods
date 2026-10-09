#!/usr/bin/env bash
# End-to-end dry run of the BBN flow in a throwaway repo (no network, nothing outside the temp dir):
# plan -> checkpoint -> 2 worktrees -> simulated coder output -> gate -> review -> queue ->
# merge in plan order -> report -> cleanup, then the same flow driven by the bbn-run.mjs harness.
# usage: bash tests/smoke.sh
set -u
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
command -v node >/dev/null 2>&1 || { echo "skip: node not installed"; exit 0; }
T="$(mktemp -d "${TMPDIR:-/tmp}/bbn-smoke.XXXXXX")"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" BBN_DOCTOR_OFFLINE=1 TMPDIR="$T" BBN_GATE_CMD="test -f done.txt"
unset BBN_BASE CLAUDE_PLUGIN_ROOT 2>/dev/null || true
git config --global user.name "bbn smoke"; git config --global user.email "bbn@test.invalid"; git config --global init.defaultBranch main

pass=0; fail=0
step() { local name="$1" want="$2"; shift 2; local out; out="$("$@" 2>&1)"; local got=$?
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); echo "ok   $name"; else fail=$((fail + 1)); echo "FAIL $name (exit $got, want $want)"; echo "$out" | sed 's/^/     /'; fi; }
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

git init -q --bare "$T/origin.git"; git clone -q "$T/origin.git" "$T/shop" 2>/dev/null; cd "$T/shop" || exit 1
mkdir -p src/api src/ui; echo api > src/api/index.txt; echo ui > src/ui/index.txt; touch done.txt
git add -A; git commit -qm init; git push -q origin main

# 1. plan written by the hub (BBN)
mkdir -p .bbn
cat > .bbn/plan.json <<'JSON'
{ "version": 1, "title": "checkout", "status": "draft",
  "goal": "add a checkout API and its UI",
  "streams": [
    { "slug": "checkout-ui", "role": "claude-code", "paths": ["src/ui/"], "dependsOn": ["checkout-api"], "acceptance": ["test -f src/ui/checkout.txt"] },
    { "slug": "checkout-api", "role": "claude-code", "paths": ["src/api/"], "acceptance": ["test -f src/api/checkout.txt"] } ] }
JSON
step "plan check" 0 node "$S/bbn-plan.mjs" check
step "apply refused before checkpoint" 3 node "$S/bbn-plan.mjs" apply --apply
step "plan accept (checkpoint)" 0 node "$S/bbn-plan.mjs" accept
step "apply dry-run" 0 node "$S/bbn-plan.mjs" apply
check "dry-run created nothing" '[ "$(git worktree list | wc -l | tr -d " ")" = 1 ]'
step "apply --apply creates worktrees" 0 node "$S/bbn-plan.mjs" apply --apply
API="$T/shop-checkout-api"; UI="$T/shop-checkout-ui"
check "two worktrees exist" '[ -d "$API" ] && [ -d "$UI" ]'
check "ownership carries plan paths + deps" 'grep -q "\"src/ui/\"" "$UI/.bbn/ownership.json" && grep -q checkout-api "$UI/.bbn/ownership.json"'

# 2. coder output (what claude-code commits in each worktree)
(cd "$API" && echo "POST /checkout" > src/api/checkout.txt && git add -A && git commit -qm "api: checkout")
(cd "$UI" && echo "checkout button" > src/ui/checkout.txt && git add -A && git commit -qm "ui: checkout")
"$S/bbn-ledger.sh" agent claude-code --turns 9 >/dev/null; "$S/bbn-ledger.sh" agent claude-code --turns 14 >/dev/null

# 3. gate + review for both
for W in "$API" "$UI"; do
  (cd "$W" && "$S/bbn-gate.sh" >/dev/null 2>&1 && "$S/bbn-review-record.sh" APPROVE --note smoke >/dev/null)
  "$S/bbn-ledger.sh" agent bbn-reviewer --turns 5 >/dev/null
done
check "both gated + approved" '[ "$(grep -c "\"event\":\"review\"" "$(git rev-parse --path-format=absolute --git-common-dir)/bbn/runs.jsonl")" = 2 ]'

# 4. queue respects plan order
out="$(node "$S/bbn-queue.mjs" 2>&1)"
check "queue: api before ui, both ready" '[ "$(echo "$out" | awk "\$1==\"1\"{print \$2}")" = feature/checkout-api ] && echo "$out" | grep -q "^2  feature/checkout-ui *yes"'

# 5. merge out of order is refused, in order succeeds
step "merge ui first refused (plan order)" 3 sh -c "cd '$UI' && '$S/bbn-merge.sh' --apply"
step "merge api" 0 sh -c "cd '$API' && '$S/bbn-merge.sh' --apply"
step "merge ui (rebases onto api)" 0 sh -c "cd '$UI' && '$S/bbn-merge.sh' --apply"
check "main has both features" '[ -f src/api/checkout.txt ] && [ -f src/ui/checkout.txt ]'
check "nothing pushed" '[ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$(git rev-parse origin/main)" ] && [ "$(git rev-parse origin/main)" != "$(git rev-parse main)" ]'

# 6. report + cleanup
out="$(node "$S/bbn-report.mjs" 2>&1)"
check "report: 2 merges, agent turns" 'echo "$out" | grep -q "merges: .*merged 2" && echo "$out" | grep -q "claude-code .*runs 2, turns 23"'
step "cleanup --apply --delete-branches" 0 "$S/bbn-cleanup.sh" --apply --delete-branches --base main
check "worktrees and merged branches gone" '[ ! -d "$API" ] && [ ! -d "$UI" ] && ! git rev-parse --verify --quiet refs/heads/feature/checkout-ui >/dev/null'

# 7. automatic loop: bbn-run.mjs does every mechanical step; the test plays the agents (build, fix, review)
unset BBN_GATE_CMD   # no lint/test in this repo: the harness gates on the plan's acceptance checks
git clone -q "$T/origin.git" "$T/auto" 2>/dev/null; cd "$T/auto" || exit 1
act() { node "$S/bbn-run.mjs" --json "$@" 2>/dev/null | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));console.log(j.actions.map((a)=>a.do+(a.stream?":"+a.stream:"")).join(" "))'; }
check "auto: no plan -> plan" '[ "$(act)" = plan ]'
mkdir -p .bbn; cat > .bbn/plan.json <<'JSON'
{ "version": 1, "title": "pay", "status": "draft", "goal": "add a payments API and its UI",
  "streams": [
    { "slug": "pay-ui", "role": "claude-code", "paths": ["src/ui/"], "dependsOn": ["pay-api"], "acceptance": ["test -f src/ui/pay.txt"] },
    { "slug": "pay-api", "role": "codex", "paths": ["src/api/"], "acceptance": ["test -f src/api/pay.txt"] } ] }
JSON
check "auto: draft -> approve-plan" '[ "$(act)" = approve-plan ]'
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null
PA="$T/auto-pay-api"; PU="$T/auto-pay-ui"
check "auto: dry-run changes nothing" '[ "$(act)" = "create:pay-api wait:pay-ui" ] && [ ! -d "$PA" ]'
check "auto: --apply creates api only, ui waits" '[ "$(act --apply)" = "build:pay-api wait:pay-ui" ] && [ -d "$PA" ] && [ ! -d "$PU" ]'
(cd "$PA" && echo wip > src/api/wip.txt && git add -A && git commit -qm "api: wip")
check "auto: failing acceptance -> fix" '[ "$(act --apply)" = "fix:pay-api wait:pay-ui" ]'
(cd "$PA" && echo pay > src/api/pay.txt && git add -A && git commit -qm "api: pay")
check "auto: checks + gate pass -> review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ] && [ -x "$PA/.bbn/gate.sh" ]'
check "auto: generated gate runs each check in its own shell" 'grep -qx "(" "$PA/.bbn/gate.sh"'
acc() { node -e 'const f=".bbn/plan.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.streams[1].acceptance=process.argv.slice(1);fs.writeFileSync(f,JSON.stringify(p))' "$@"; node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null; }
acc "test -f src/api/pay.txt" "test -f src/api/missing.txt"
check "auto: changed acceptance re-runs the checks on the same commit" '[ "$(act --apply)" = "fix:pay-api wait:pay-ui" ]'
acc "test -f src/api/pay.txt"
check "auto: restored acceptance -> checks + gate again -> review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ]'
(cd "$PA" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
(cd "$PA" && printf 'pay \n' > src/api/pay.txt && git commit -qam "api: trailing space")
check "auto: whitespace-only change needs a new review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ]'
(cd "$PA" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
check "auto: approve -> api merged, ui created" '[ "$(act --apply)" = build:pay-ui ] && [ -f src/api/pay.txt ] && [ -d "$PU" ]'
(cd "$PU" && echo pay > src/ui/pay.txt && git add -A && git commit -qm "ui: pay")
check "auto: ui -> review" '[ "$(act --apply)" = review:pay-ui ]'
(cd "$PU" && "$S/bbn-review-record.sh" REQUEST_CHANGES --base main --note "name the button" >/dev/null)
check "auto: request changes -> fix" '[ "$(act --apply)" = fix:pay-ui ]'
(cd "$PU" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
git worktree add -q -b other "$T/auto-other" 2>/dev/null   # merged but not in the plan: cleanup must leave it
check "auto: merge, cleanup, verify -> done" '[ "$(act --apply)" = done ] && [ ! -d "$PA" ] && [ ! -d "$PU" ] && [ -f src/ui/pay.txt ]'
check "auto: cleanup leaves worktrees outside the plan" '[ -d "$T/auto-other" ]'
check "auto: done is stable, nothing pushed" '[ "$(act --apply)" = done ] && [ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$(git rev-parse origin/main)" ]'
step "auto: verify passes on base" 0 node "$S/bbn-run.mjs" verify
printf '#!/bin/sh\nexit 1\n' > .bbn/gate.sh; chmod +x .bbn/gate.sh
check "auto: a new .bbn/gate.sh re-runs verify" '[ "$(act --apply)" = replan ]'
chmod -x .bbn/gate.sh
check "auto: a non-executable .bbn/gate.sh fails verify" '[ "$(act --apply)" = replan ]'
rm .bbn/gate.sh
check "auto: gate removed -> verified again" '[ "$(act --apply)" = done ]'
node -e 'const f=".bbn/plan.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.streams[1].summary="another api";fs.writeFileSync(f,JSON.stringify(p))'
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null
check "auto: a changed stream with the same slug is not taken as merged" '[ "$(act)" = stop:pay-api ]'

# 8. an approved stream never merges before the stream it depends on
git clone -q "$T/origin.git" "$T/deps" 2>/dev/null; cd "$T/deps" || exit 1
mkdir -p .bbn; cat > .bbn/plan.json <<'JSON'
{ "version": 1, "title": "deps", "status": "draft", "goal": "a then b",
  "streams": [
    { "slug": "dep-a", "role": "claude-code", "paths": ["src/api/"], "acceptance": ["test -f src/api/a.txt"] },
    { "slug": "dep-b", "role": "claude-code", "paths": ["src/ui/"], "dependsOn": ["dep-a"], "acceptance": ["test -f src/ui/b.txt"] } ] }
JSON
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null; node "$S/bbn-plan.mjs" apply --apply >/dev/null 2>&1
(cd "$T/deps-dep-b" && echo b > src/ui/b.txt && git add -A && git commit -qm b && "$S/bbn-gate.sh" >/dev/null 2>&1; true)
act --apply >/dev/null; (cd "$T/deps-dep-b" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
check "auto: approved dependent waits for its dependency" '[ "$(act --apply)" = "build:dep-a wait:dep-b" ] && [ ! -f src/ui/b.txt ]'

echo "---"; echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
