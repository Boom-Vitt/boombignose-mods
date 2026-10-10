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
IN="$(node -p 'require("./.bbn/plan.json").integration')"
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
  (cd "$W" && "$S/bbn-gate.sh" >/dev/null 2>&1 && "$S/bbn-review-record.sh" APPROVE --base "$IN" --note smoke >/dev/null)
  "$S/bbn-ledger.sh" agent bbn-reviewer --turns 5 >/dev/null
done
check "both gated + approved" '[ "$(grep -c "\"event\":\"review\"" "$(git rev-parse --path-format=absolute --git-common-dir)/bbn/runs.jsonl")" = 2 ]'

# 4. queue respects plan order
out="$(node "$S/bbn-queue.mjs" --base "$IN" 2>&1)"
check "queue: api before ui, both ready" '[ "$(echo "$out" | awk "\$1==\"1\"{print \$2}")" = feature/checkout-api ] && echo "$out" | grep -q "^2  feature/checkout-ui *yes"'

# 5. merge out of order is refused, in order succeeds
step "merge ui first refused (plan order)" 3 sh -c "cd '$UI' && '$S/bbn-merge.sh' --apply --base '$IN'"
step "merge api" 0 sh -c "cd '$API' && '$S/bbn-merge.sh' --apply --base '$IN'"
step "merge ui (rebases onto api)" 0 sh -c "cd '$UI' && '$S/bbn-merge.sh' --apply --base '$IN'"
git worktree add -q "$T/shop-final" "$IN"
step "final review" 0 sh -c "cd '$T/shop-final' && '$S/bbn-review-record.sh' APPROVE --base main"
step "final merge" 0 sh -c "cd '$T/shop-final' && '$S/bbn-merge.sh' --apply --base main --no-rebase"
check "main has both features" '[ -f src/api/checkout.txt ] && [ -f src/ui/checkout.txt ]'
check "nothing pushed" '[ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$(git rev-parse origin/main)" ] && [ "$(git rev-parse origin/main)" != "$(git rev-parse main)" ]'

# 6. report + cleanup
out="$(node "$S/bbn-report.mjs" 2>&1)"
check "report: 3 merges, agent turns" 'echo "$out" | grep -q "merges: .*merged 3" && echo "$out" | grep -q "claude-code .*runs 2, turns 23"'
step "cleanup --apply --delete-branches" 0 "$S/bbn-cleanup.sh" --apply --delete-branches --base main
check "worktrees and merged branches gone" '[ ! -d "$API" ] && [ ! -d "$UI" ] && ! git rev-parse --verify --quiet refs/heads/feature/checkout-ui >/dev/null'

# 7. automatic loop: the harness runs mechanical steps; this test plays the agents.
unset BBN_GATE_CMD
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
IN="$(node -p 'require("./.bbn/plan.json").integration')"
check "auto: accept names the integration branch" 'echo "$IN" | grep -qE "^bbn/pay-[0-9a-f]{6}$"'
PA="$T/auto-pay-api"; PU="$T/auto-pay-ui"; FINAL="$T/auto-${IN//\//-}"
# shellcheck disable=SC2034 # Used by check's eval.
MAIN_START="$(git rev-parse main)"
check "auto: dry-run changes nothing" '[ "$(act)" = integrate ] && [ ! -d "$PA" ] && ! git rev-parse --verify --quiet "$IN" >/dev/null'
check "auto: --apply creates api only, ui waits" '[ "$(act --apply)" = "build:pay-api wait:pay-ui" ] && [ -d "$PA" ] && [ ! -d "$PU" ]'
check "auto: integration has no upstream" '[ -z "$(git for-each-ref --format="%(upstream)" "refs/heads/$IN")" ]'
(cd "$PA" && echo wip > src/api/wip.txt && git add -A && git commit -qm "api: wip")
check "auto: failing acceptance -> fix" '[ "$(act --apply)" = "fix:pay-api wait:pay-ui" ]'
(cd "$PA" && echo pay > src/api/pay.txt && echo outside > src/ui/intruder.txt && git add -A && git commit -qm "api: outside paths")
check "auto: file outside stream paths -> fix" '[ "$(act --apply)" = "fix:pay-api wait:pay-ui" ] && grep -q "outside the stream paths: src/ui/intruder.txt" "$(git -C "$PA" rev-parse --absolute-git-dir)/bbn/accept.json"'
(cd "$PA" && git rm -q src/ui/intruder.txt && git commit -qm "api: restore ownership")
check "auto: checks + gate pass -> review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ] && [ -x "$PA/.bbn/gate.sh" ]'
check "auto: generated gate runs each check in its own shell" 'grep -qx "(" "$PA/.bbn/gate.sh"'
(cd "$PA" && "$S/bbn-review-record.sh" APPROVE --base "$IN" >/dev/null && rm "$(git rev-parse --absolute-git-dir)/bbn/review.json")
step "merge: stream refuses a base other than the integration branch" 3 sh -c "cd '$PA' && '$S/bbn-merge.sh' --apply --base main --ignore-order"
step "scan: clean branch passes" 0 sh -c "cd '$PA' && node '$S/bbn-plan.mjs' scan --base '$IN'"
acc() { node -e 'const f=".bbn/plan.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.streams[1].acceptance=process.argv.slice(1);fs.writeFileSync(f,JSON.stringify(p))' "$@"; node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null; }
acc "test -f src/api/pay.txt" "test -f src/api/missing.txt"
check "auto: changed acceptance re-runs the checks on the same commit" '[ "$(act --apply)" = "fix:pay-api wait:pay-ui" ]'
acc "test -f src/api/pay.txt"
check "auto: restored acceptance -> checks + gate again -> review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ]'
(cd "$PA" && "$S/bbn-review-record.sh" APPROVE --base "$IN" >/dev/null)
(cd "$PA" && printf 'pay \n' > src/api/pay.txt && git commit -qam "api: trailing space")
check "auto: whitespace-only change needs a new review" '[ "$(act --apply)" = "review:pay-api wait:pay-ui" ]'
echo unfinished > src/api/main-only.txt
check "auto: main untracked files do not flip a running plan" '[ "$(act)" = "review:pay-api wait:pay-ui" ]'
rm src/api/main-only.txt
(cd "$PA" && "$S/bbn-review-record.sh" APPROVE --base "$IN" >/dev/null)
check "auto: approve -> api merged into integration, ui created" '[ "$(act --apply)" = build:pay-ui ] && git cat-file -e "$IN:src/api/pay.txt" && [ -d "$PU" ] && [ ! -f src/api/pay.txt ]'
(cd "$PU" && echo pay > src/ui/pay.txt && git add -A && git commit -qm "ui: pay")
check "auto: ui -> review" '[ "$(act --apply)" = review:pay-ui ]'
(cd "$PU" && "$S/bbn-review-record.sh" REQUEST_CHANGES --base "$IN" --note "name the button" >/dev/null)
check "auto: request changes -> fix" '[ "$(act --apply)" = fix:pay-ui ]'
(cd "$PU" && "$S/bbn-review-record.sh" APPROVE --base "$IN" >/dev/null)
git worktree add -q -b other "$T/auto-other" 2>/dev/null
check "auto: all streams merged -> final review" '[ "$(act --apply)" = final-review ] && [ -d "$FINAL" ] && [ -x "$FINAL/.bbn/gate.sh" ] && [ ! -d "$PA" ] && [ ! -d "$PU" ]'
check "auto: main untouched until final review" '[ "$(git rev-parse main)" = "$MAIN_START" ] && [ ! -f src/api/pay.txt ] && [ ! -f src/ui/pay.txt ]'
out="$(node "$S/bbn-run.mjs" --json)"
if echo "$out" | node -e 'const j=JSON.parse(require("fs").readFileSync(0));process.exit(j.base==="main"&&j.integration===process.argv[1]&&j.actions[0].base==="main"&&j.actions[0].integration===j.integration?0:1)' "$IN"; then
  check "auto: final action uses target base and names integration" true
else check "auto: final action uses target base and names integration" false; fi
printf '#!/bin/sh\nexit 1\n' > .bbn/gate.sh; chmod +x .bbn/gate.sh
check "auto: a new .bbn/gate.sh re-runs verify" '[ "$(act --apply)" = replan ]'
chmod -x .bbn/gate.sh
check "auto: a non-executable .bbn/gate.sh fails verify" '[ "$(act --apply)" = replan ]'
rm .bbn/gate.sh
check "auto: gate removed -> verified again" '[ "$(act --apply)" = final-review ]'
(cd "$FINAL" && echo outside > stray.txt && git add stray.txt && git commit -qm "outside final paths")
check "auto: final paths check -> replan" '[ "$(act --apply)" = replan ] && grep -q "outside the plan paths: stray.txt" "$(git rev-parse --git-common-dir)/bbn/verify.json"'
(cd "$FINAL" && git rm -q stray.txt && git commit -qm "restore final paths")
check "auto: final paths restored -> review" '[ "$(act --apply)" = final-review ]'
(cd "$FINAL" && "$S/bbn-review-record.sh" REQUEST_CHANGES --base main --note "add a fix stream" >/dev/null)
check "auto: final request changes -> replan" '[ "$(act --apply)" = replan ]'
(cd "$FINAL" && "$S/bbn-review-record.sh" BLOCK --base main >/dev/null)
check "auto: final block -> stop" '[ "$(act --apply)" = stop ]'
for n in 1 2; do (cd "$FINAL" && "$S/bbn-review-record.sh" REQUEST_CHANGES --base main --note "request $n" >/dev/null); done
check "auto: repeated final requests -> stop" '[ "$(act --apply)" = stop ]'
echo moved > src/api/base.txt; git add src/api/base.txt; git commit -qm "target moved"
check "auto: target moved -> resolve" '[ "$(act --apply)" = resolve ]'
(cd "$FINAL" && git merge -q --no-ff --no-edit main && echo resolved >> src/ui/pay.txt && git commit -qam "resolve final review changes")
check "auto: target merged in -> new final review" '[ "$(act --apply)" = final-review ]'
(cd "$FINAL" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
cp -R "$S/.." "$T/ask-plugin"
node -e 'const fs=require("fs"),f=process.argv[1],c=JSON.parse(fs.readFileSync(f));c.automation.merge="ask";fs.writeFileSync(f,JSON.stringify(c))' "$T/ask-plugin/bbn.config.json"
out="$(node "$T/ask-plugin/scripts/bbn-run.mjs" --json)"
if echo "$out" | node -e 'const j=JSON.parse(require("fs").readFileSync(0)),a=j.actions[0];process.exit(a.do==="ask-merge"&&a.base==="main"&&a.worktree===require("fs").realpathSync(process.argv[1])&&a.cmd.includes(" --apply --base ")&&a.cmd.endsWith(" --no-rebase")?0:1)' "$FINAL"; then
  check "auto: final ask-merge uses target and no rebase" true
else check "auto: final ask-merge uses target and no rebase" false; fi
node -e 'const fs=require("fs");fs.appendFileSync(process.argv[1],JSON.stringify({event:"run.merge",branch:process.argv[2],head:process.argv[3],code:5})+"\n")' "$(git rev-parse --git-common-dir)/bbn/runs.jsonl" "$IN" "$(git rev-parse "$IN")"
check "auto: stale final merge -> review again" '[ "$(act --apply)" = final-review ]'
(cd "$FINAL" && "$S/bbn-review-record.sh" APPROVE --base main >/dev/null)
# shellcheck disable=SC2034 # Used by check's eval.
BEFORE_FINAL="$(git rev-parse main)"
# shellcheck disable=SC2034 # Used by check's eval.
RESULT="$(act --apply)"
check "auto: final approve -> one merge into main" '[ "$RESULT" = done ] && [ "$(git rev-list --count --first-parent "$BEFORE_FINAL..main")" = 1 ] && [ "$(git log -1 --format=%P main | wc -w | tr -d " ")" = 2 ]'
check "auto: merge, cleanup, final -> done" '[ "$RESULT" = done ] && [ ! -d "$PA" ] && [ ! -d "$PU" ] && [ ! -d "$FINAL" ] && [ -f src/ui/pay.txt ] && git rev-parse --verify --quiet "$IN" >/dev/null'
check "auto: cleanup leaves worktrees outside the plan" '[ -d "$T/auto-other" ]'
check "auto: done is stable, nothing pushed" '[ "$(act --apply)" = done ] && [ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$(git rev-parse origin/main)" ]'
step "auto: verify passes on integration" 0 node "$S/bbn-run.mjs" verify
node -e 'const f=".bbn/plan.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));p.streams[1].summary="another api";fs.writeFileSync(f,JSON.stringify(p))'
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null
check "auto: a changed stream with the same slug is not taken as merged" '[ "$(act --apply)" = stop:pay-api ]'

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
IN="$(node -p 'require("./.bbn/plan.json").integration')"
act --apply >/dev/null; (cd "$T/deps-dep-b" && "$S/bbn-review-record.sh" APPROVE --base "$IN" >/dev/null)
check "auto: approved dependent waits for its dependency" '[ "$(act --apply)" = "build:dep-a wait:dep-b" ] && [ ! -f src/ui/b.txt ]'

# 9. an ignored ownership path cannot be carried to a worktree.
git init -q "$T/ignored"; cd "$T/ignored" || exit 1
printf 'cache/\n' > .gitignore; git add .gitignore; git commit -qm init
mkdir -p .bbn; cat > .bbn/plan.json <<'JSON'
{"version":1,"title":"ignored","status":"draft","goal":"g","streams":[{"slug":"cache","role":"codex","paths":["cache/"],"acceptance":["true"]}]}
JSON
step "plan: gitignored owned path is an error" 1 node "$S/bbn-plan.mjs" check

# 10. renaming an unowned source into an owned tree still changes the source path.
git init -q "$T/rename"; cd "$T/rename" || exit 1
echo source > unowned.txt; git add unowned.txt; git commit -qm init
mkdir -p .bbn; cat > .bbn/plan.json <<'JSON'
{"version":1,"title":"rename","status":"draft","goal":"g","streams":[{"slug":"rename","role":"codex","paths":["owned/"],"acceptance":["true"]}]}
JSON
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null; act --apply >/dev/null
IN="$(node -p 'require("./.bbn/plan.json").integration')"
RW="$T/rename-rename"
(cd "$RW" && mkdir owned && git mv unowned.txt owned/moved.txt && git commit -qm "rename across ownership")
check "auto: rename from outside stream paths -> fix" '[ "$(act --apply)" = fix:rename ] && grep -q "outside the stream paths: unowned.txt" "$(git -C "$RW" rev-parse --absolute-git-dir)/bbn/accept.json"'
git branch -f "$IN" feature/rename
step "auto: final paths union refuses an unowned rename source" 1 node "$S/bbn-run.mjs" verify
check "auto: final rename reports the unowned source" 'grep -q "outside the plan paths: unowned.txt" "$(git rev-parse --git-common-dir)/bbn/verify.json"'

# 11. a deleted secret still ships in history; keep this fixture out of the clean automatic flow.
git clone -q "$T/origin.git" "$T/secret" 2>/dev/null; cd "$T/secret" || exit 1
mkdir -p .bbn; cat > .bbn/plan.json <<'JSON'
{"version":1,"title":"secret","status":"draft","goal":"g","streams":[{"slug":"secret","role":"codex","paths":["src/api/"],"acceptance":["true"]}]}
JSON
node "$S/bbn-plan.mjs" accept --by reviewer >/dev/null; act --apply >/dev/null
IN="$(node -p 'require("./.bbn/plan.json").integration')"
SW="$T/secret-secret"
(cd "$SW" && node -e 'require("fs").writeFileSync("src/api/leak.txt", "AK"+"IA"+"A".repeat(16)+"\n")' && git add -A && git commit -qm "unsafe fixture")
step "scan: secret in a commit refuses the merge" 3 sh -c "cd '$SW' && '$S/bbn-merge.sh' --apply --base '$IN'"
check "auto: secret scan failure -> fix" '[ "$(act --apply)" = fix:secret ] && grep -q secret-scan "$(git -C "$SW" rev-parse --absolute-git-dir)/bbn/accept.json"'
# shellcheck disable=SC2034 # Used by check's eval.
SECRET_SHA="$(git -C "$SW" rev-parse --short=7 HEAD)"
(cd "$SW" && git rm -q src/api/leak.txt && git commit -qm "remove unsafe fixture")
out="$(cd "$SW" && node "$S/bbn-plan.mjs" scan --base "$IN")"
# shellcheck disable=SC2034 # Used by check's eval.
rc=$?
check "scan: deleted secret reports its commit and exits 3" '[ "$rc" = 3 ] && echo "$out" | grep -qx "src/api/leak.txt:1 aws-access-key @$SECRET_SHA"'
step "scan: deleted secret still refuses the merge" 3 sh -c "cd '$SW' && '$S/bbn-merge.sh' --apply --base '$IN'"
step "scan: deleted secret refuses a dry-run merge" 3 sh -c "cd '$SW' && '$S/bbn-merge.sh' --base '$IN'"

echo "---"; echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
