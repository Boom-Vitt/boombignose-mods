#!/usr/bin/env bash
# Plain bash tests for the BBN scripts. Creates throwaway git repos in a temp dir and deletes them.
# usage: bash tests/run.sh
set -u
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/bbn-tests.XXXXXX")"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig" BBN_DOCTOR_OFFLINE=1 TMPDIR="$T"
unset BBN_BASE BBN_GATE_CMD CLAUDE_PLUGIN_ROOT 2>/dev/null || true
git config --global user.name "bbn test"; git config --global user.email "bbn@test.invalid"
git config --global init.defaultBranch main; git config --global advice.detachedHead false

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/     /'; }
expect_code() { # name expected cmd...
  local name="$1" want="$2"; shift 2; local out; out="$("$@" 2>&1)"; local got=$?
  if [ "$got" = "$want" ]; then ok "$name"; else bad "$name (exit $got, want $want)" "$out"; fi
}
q() { "$@" >/dev/null 2>&1; }

# --- syntax ---
for f in "$S"/*.sh "$S"/lib/*.sh; do bash -n "$f" && ok "bash -n $(basename "$f")" || bad "bash -n $f"; done

# --- config ---
if command -v node >/dev/null 2>&1; then
  expect_code "config valid" 0 node "$S/bbn-config-check.mjs"
  sed 's/"neverForcePush": true/"neverForcePush": false/' "$S/../bbn.config.json" > "$T/bad.json"
  expect_code "config rejects neverForcePush=false" 1 node "$S/bbn-config-check.mjs" "$T/bad.json"
fi

# --- fixture: origin + clone ---
git init -q --bare "$T/origin.git"
git clone -q "$T/origin.git" "$T/app" 2>/dev/null
cd "$T/app" || exit 1
echo base > README.md; printf 'FOO=fake\n' > .env; echo .env > .gitignore
git add README.md .gitignore; git commit -qm init; git push -q origin main

# --- worktree-new ---
expect_code "worktree-new rejects bad slug" 2 "$S/worktree-new.sh" "../evil"
expect_code "worktree-new feat-a" 0 "$S/worktree-new.sh" feat-a
A="$T/app-feat-a"
[ -d "$A" ] && ok "worktree dir created" || bad "worktree dir created"
grep -q '^BBN_DEV_PORT=' "$A/.env.worktree" && grep -q '^FOO=fake' "$A/.env.worktree" && ok ".env.worktree has port + copied env" || bad ".env.worktree"
[ -f "$A/.bbn/ownership.json" ] && ok "ownership.json written" || bad "ownership.json"
[ -z "$(git -C "$A" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" ] && ok "feature branch has no upstream (--no-track)" || bad "feature branch tracks an upstream"
[ -z "$(git -C "$A" status --porcelain)" ] && ok "bbn files excluded from git status" || bad "bbn files excluded" "$(git -C "$A" status --porcelain)"
expect_code "worktree-new refuses duplicate" 3 "$S/worktree-new.sh" feat-a
expect_code "worktree budget enforced" 3 env BBN_MAX_WORKTREES=1 "$S/worktree-new.sh" feat-x

# --- gate ---
cd "$A" || exit 1
echo a > a.txt; git add a.txt; git commit -qm "feat a"
expect_code "gate pass (BBN_GATE_CMD=true)" 0 env BBN_GATE_CMD=true "$S/bbn-gate.sh"
grep -q '"result": "pass"' "$(git rev-parse --absolute-git-dir)/bbn/gate.json" && ok "gate.json recorded in git dir" || bad "gate.json"
expect_code "gate fail (BBN_GATE_CMD=false)" 1 env BBN_GATE_CMD=false "$S/bbn-gate.sh" --no-record
expect_code "gate empty project -> 2" 2 "$S/bbn-gate.sh" --no-record
mkdir -p .bbn && printf '#!/bin/sh\nexit 0\n' > .bbn/gate.sh
expect_code "gate: non-executable .bbn/gate.sh -> 1" 1 "$S/bbn-gate.sh" --no-record
rm .bbn/gate.sh
if command -v npm >/dev/null 2>&1; then
  mkdir -p "$T/js" && cd "$T/js" && git init -q .
  printf '{"name":"t","version":"1.0.0","scripts":{"lint":"node -e 0","test":"node -e process.exit(1)"}}\n' > package.json
  expect_code "gate npm: lint ok + test fail -> 1" 1 "$S/bbn-gate.sh" --no-record
  printf '{"name":"t","version":"1.0.0","scripts":{"lint":"node -e 0","test":"node -e 0"}}\n' > package.json
  expect_code "gate npm: all pass -> 0" 0 "$S/bbn-gate.sh" --no-record
  cd "$A" || exit 1
fi

# --- merge ---
main_before="$(git -C "$T/app" rev-parse main)"
expect_code "merge dry-run refuses without review" 3 "$S/bbn-merge.sh"
expect_code "merge --apply refuses without review" 3 "$S/bbn-merge.sh" --apply
q "$S/bbn-review-record.sh" APPROVE --note 'looks "good"'
grep -q '"verdict": "APPROVE"' "$(git rev-parse --absolute-git-dir)/bbn/review.json" && ok "review recorded" || bad "review recorded"
expect_code "merge dry-run ready" 0 "$S/bbn-merge.sh"
[ "$(git -C "$T/app" rev-parse main)" = "$main_before" ] && ok "dry-run changed nothing" || bad "dry-run changed main"
expect_code "merge --apply blocked by failing gate" 1 env BBN_GATE_CMD=false "$S/bbn-merge.sh" --apply
[ "$(git -C "$T/app" rev-parse main)" = "$main_before" ] && ok "failed gate left main alone" || bad "failed gate moved main"

# upstream moves on -> rebase needed
git clone -q "$T/origin.git" "$T/other" 2>/dev/null
(cd "$T/other" && echo up > up.txt && git add up.txt && git commit -qm upstream && git push -q origin main)
remote_before="$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)"
expect_code "merge --apply (rebase + gate + merge)" 0 env BBN_GATE_CMD=true "$S/bbn-merge.sh" --apply
[ -f "$T/app/a.txt" ] && [ -f "$T/app/up.txt" ] && ok "main has feature + upstream" || bad "main content"
[ "$(git -C "$T/app" log -1 --format=%P main | wc -w | tr -d ' ')" = 2 ] && ok "merge commit is --no-ff" || bad "no merge commit"
[ "$(git ls-remote "$T/origin.git" refs/heads/main | cut -f1)" = "$remote_before" ] && ok "nothing pushed" || bad "origin changed"

# stale review
cd "$T/app" || exit 1
q "$S/worktree-new.sh" feat-b
B="$T/app-feat-b"; cd "$B" || exit 1
echo b > b.txt; git add b.txt; git commit -qm "feat b"
q "$S/bbn-review-record.sh" APPROVE
echo b2 >> b.txt; git commit -qam "more b"
expect_code "merge refuses stale review (exit 5)" 5 env BBN_GATE_CMD=true "$S/bbn-merge.sh" --apply

# --- status ---
cd "$T/app" || exit 1
out="$(env BBN_BASE=main "$S/bbn-status.sh" 2>&1)"
echo "$out" | grep -q 'feature/feat-b' && ok "status lists feature/feat-b" || bad "status" "$out"

# --- cleanup ---
out="$("$S/bbn-cleanup.sh" --base main 2>&1)"
echo "$out" | grep -q 'would remove worktree .*app-feat-a' && echo "$out" | grep -q 'keep feature/feat-b: not merged' \
  && ok "cleanup dry-run: merged listed, unmerged kept" || bad "cleanup dry-run" "$out"
[ -d "$A" ] && ok "dry-run removed nothing" || bad "dry-run removed"
q "$S/bbn-cleanup.sh" --base main --apply
[ ! -d "$A" ] && [ -d "$B" ] && ok "cleanup --apply removed merged only" || bad "cleanup apply"
git rev-parse --verify --quiet refs/heads/feature/feat-a >/dev/null && ok "branch kept without --delete-branches" || bad "branch deleted without flag"
q "$S/worktree-new.sh" feat-c; git -C "$T/app" merge -q --no-ff -m m feature/feat-c 2>/dev/null
q "$S/bbn-cleanup.sh" --base main --apply --delete-branches
! git rev-parse --verify --quiet refs/heads/feature/feat-c >/dev/null && git rev-parse --verify --quiet refs/heads/feature/feat-b >/dev/null \
  && ok "--delete-branches deletes merged only" || bad "--delete-branches"

# --- doctor ---
out="$("$S/bbn-doctor.sh" --offline 2>&1)"
echo "$out" | grep -q 'bbn.config.json: OK\|node not found' && echo "$out" | grep -q 'result:' && ok "doctor runs offline" || bad "doctor" "$out"
echo "$out" | grep -qi 'pplx-' && bad "doctor leaked a key-like value" || ok "doctor prints no key values"
mkdir -p "$T/oldgit"; REALGIT="$(command -v git)"
printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "git version 2.30.1"; else exec "%s" "$@"; fi\n' "$REALGIT" > "$T/oldgit/git"; chmod +x "$T/oldgit/git"
out="$(PATH="$T/oldgit:$PATH" "$S/bbn-doctor.sh" --offline 2>&1)"
echo "$out" | grep -q 'FAIL  git 2.30.1 is older than 2.39' && ok "doctor fails on git < 2.39 (patch-id --verbatim)" || bad "doctor git version" "$out"


# ===== v0.4.0 =====
cd "$T/app" || exit 1
ROOT="$(cd "$S/.." && pwd)"

# --- gate timeout ---
t0=$(date +%s)
out="$(cd "$B" && BBN_GATE_TIMEOUT=1 BBN_GATE_CMD="sleep 20" "$S/bbn-gate.sh" --no-record 2>&1)"; rc=$?
el=$(( $(date +%s) - t0 ))
[ "$rc" = 1 ] && echo "$out" | grep -q TIMEOUT && [ "$el" -lt 8 ] && ok "gate step timeout -> fail in ${el}s" || bad "gate timeout (rc=$rc el=${el}s)" "$out"

# --- ledger ---
LED="$(git rev-parse --path-format=absolute --git-common-dir)/bbn/runs.jsonl"
[ -s "$LED" ] && ok "ledger written in common git dir" || bad "ledger missing"
if command -v node >/dev/null 2>&1; then
  node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n");l.forEach(x=>JSON.parse(x));const ev=new Set(l.map(x=>JSON.parse(x).event));for(const e of ["worktree.create","gate","review","merge","cleanup"]) if(!ev.has(e)) {console.error("missing "+e);process.exit(1)}' "$LED" \
    && ok "ledger lines are JSON with worktree/gate/review/merge/cleanup events" || bad "ledger content"
fi
expect_code "ledger agent rejects unknown role" 2 "$S/bbn-ledger.sh" agent nobody --turns 3
expect_code "ledger agent requires integer turns" 2 "$S/bbn-ledger.sh" agent codex --turns x
expect_code "ledger agent records" 0 "$S/bbn-ledger.sh" agent codex --turns 12 --status ok

if command -v node >/dev/null 2>&1; then
  # --- report ---
  out="$(node "$S/bbn-report.mjs" 2>&1)"
  echo "$out" | grep -q 'codex .*runs 1, turns 12, max 12/40' && ok "report shows agent turns vs budget" || bad "report" "$out"
  expect_code "report --strict ok within budget" 0 node "$S/bbn-report.mjs" --strict
  q "$S/bbn-ledger.sh" agent claude-code --turns 41 --status partial
  expect_code "report --strict fails over budget" 1 node "$S/bbn-report.mjs" --strict
  node "$S/bbn-report.mjs" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);process.exit(j.agents["claude-code"].overBudget===1&&j.merges.merged>=1?0:1)})' \
    && ok "report --json counts over-budget + merges" || bad "report json"

  # --- plan ---
  cd "$T/app" || exit 1
  expect_code "plan check without plan -> 2" 2 node "$S/bbn-plan.mjs" check
  expect_code "plan init" 0 node "$S/bbn-plan.mjs" init --title demo
  expect_code "plan init refuses overwrite" 3 node "$S/bbn-plan.mjs" init
  expect_code "plan template valid" 0 node "$S/bbn-plan.mjs" check
  for qs in QUICKSTART.md QUICKSTART.en.md; do
    awk '/^```json$/{f=1;next} /^```$/{if (f) exit} f' "$S/../docs/$qs" > "$T/qs-plan.json"
    expect_code "docs/$qs example plan passes check" 0 node "$S/bbn-plan.mjs" check --file "$T/qs-plan.json"
  done
  [ -z "$(git status --porcelain)" ] && ok ".bbn/plan.json is git-excluded" || bad "plan visible to git" "$(git status --porcelain)"
  PLAN="$T/app/.bbn/plan.json"
  wplan() { printf '%s\n' "$1" > "$PLAN"; }
  S1='{"slug":"api","role":"claude-code","paths":["src/api/"],"acceptance":["t"]}'
  wplan "{\"version\":1,\"title\":\"x\",\"status\":\"draft\",\"goal\":\"g\",\"streams\":[$S1,{\"slug\":\"ui\",\"role\":\"codex\",\"paths\":[\"src/\"],\"acceptance\":[\"t\"]}]}"
  expect_code "plan rejects unordered ownership overlap" 1 node "$S/bbn-plan.mjs" check
  wplan "{\"version\":1,\"title\":\"x\",\"status\":\"draft\",\"goal\":\"g\",\"streams\":[$S1,{\"slug\":\"ui\",\"role\":\"codex\",\"paths\":[\"src/\"],\"dependsOn\":[\"api\"],\"acceptance\":[\"t\"]}]}"
  expect_code "plan allows overlap ordered by dependsOn" 0 node "$S/bbn-plan.mjs" check
  wplan "{\"version\":1,\"title\":\"x\",\"status\":\"draft\",\"goal\":\"g\",\"streams\":[{\"slug\":\"a\",\"role\":\"codex\",\"paths\":[\"a/\"],\"dependsOn\":[\"b\"],\"acceptance\":[\"t\"]},{\"slug\":\"b\",\"role\":\"codex\",\"paths\":[\"b/\"],\"dependsOn\":[\"a\"],\"acceptance\":[\"t\"]}]}"
  expect_code "plan rejects dependsOn cycle" 1 node "$S/bbn-plan.mjs" check
  wplan "{\"version\":1,\"title\":\"x\",\"status\":\"draft\",\"goal\":\"g\",\"streams\":[{\"slug\":\"a\",\"role\":\"codex\",\"paths\":[\"../x\"],\"acceptance\":[]}]}"
  expect_code "plan rejects ../ paths and missing acceptance" 1 node "$S/bbn-plan.mjs" check
  wplan "{\"version\":1,\"title\":\"x\",\"status\":\"draft\",\"goal\":\"g\",\"bogus\":1,\"streams\":[$S1]}"
  expect_code "plan rejects unknown fields" 1 node "$S/bbn-plan.mjs" check
  rm -f "$PLAN"
fi

# --- queue: conflict pre-detection ---
if command -v node >/dev/null 2>&1; then
  cd "$T/app" || exit 1
  printf 'l1\nl2\nl3\n' > shared.txt; git add shared.txt; git commit -qm shared
  q "$S/worktree-new.sh" q-one --base main; q "$S/worktree-new.sh" q-two --base main
  (cd "$T/app-q-one" && printf 'l1\nONE\nl3\n' > shared.txt && git commit -qam one)
  (cd "$T/app-q-two" && printf 'l1\nTWO\nl3\n' > shared.txt && echo big > big.txt && seq 1 50 >> big.txt && git add -A && git commit -qm two)
  out="$(node "$S/bbn-queue.mjs" --base main 2>&1)"
  echo "$out" | grep -q '! feature/q-one and feature/q-two conflict in shared.txt' && ok "queue predicts pair conflict" || bad "queue pair conflict" "$out"
  r1="$(echo "$out" | awk '$1 ~ /^[0-9]+$/ && $2=="feature/q-one"{print $1}')"; r2="$(echo "$out" | awk '$1 ~ /^[0-9]+$/ && $2=="feature/q-two"{print $1}')"
  [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" -lt "$r2" ] && ok "queue puts smaller branch first" || bad "queue order" "$out"
  (cd "$T/app-q-one" && q "$S/bbn-review-record.sh" APPROVE --base main)
  echo "$out" | grep -q "q-two" && ok "queue lists all feature branches" || bad "queue list"
  printf 'l1\nBASE\nl3\n' > shared.txt; git commit -qam base-change
  out="$(node "$S/bbn-queue.mjs" --base main --json 2>&1)"
  echo "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const x=j.queue.find(q=>q.branch==="feature/q-one");process.exit(x.baseConflicts.includes("shared.txt")?0:1)})' \
    && ok "queue predicts conflict with base (--json)" || bad "queue base conflict" "$out"
  [ -z "$(git -C "$T/app-q-one" status --porcelain)" ] && [ "$(git -C "$T/app" status --porcelain)" = "" ] && ok "queue left checkouts untouched" || bad "queue touched checkouts"
fi

# --- doctor + config guards (on a scratch copy of the plugin) ---
CP="$T/plugin-copy"; mkdir -p "$CP"; cp -R "$ROOT/." "$CP/"
printf '{"mcpServers":{"perplexity":{"type":"http","url":"https://api.perplexity.ai/mcp","headers":{"Authorization":"Bearer ${PERPLEXITY_API_KEY}"}}}}\n' > "$CP/.mcp.json"
out="$("$CP/scripts/bbn-doctor.sh" --offline 2>&1)"; rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q 'FAIL  .mcp.json sends an Authorization header' && ok "doctor fails on Authorization header (401 guard)" || bad "doctor 401 guard" "$out"
if command -v node >/dev/null 2>&1; then
  awk 'NR==2{print "tools: Read, Bash"}1' "$CP/agents/codex.md" > "$CP/x" && mv "$CP/x" "$CP/agents/codex.md"
  expect_code "config check rejects tools: allowlist (MCP hidden)" 1 node "$CP/scripts/bbn-config-check.mjs"
fi

# --- codex wrapper + harness/plan argument guards ---
cd "$T/app" || exit 1
expect_code "codex: CLI missing -> 3 (hand to claude-code)" 3 env PATH=/usr/bin:/bin "$S/bbn-codex.sh" run "x"
expect_code "codex: usage -> 2" 2 "$S/bbn-codex.sh" nope
expect_code "codex: --base without a value -> 2" 2 env PATH="$T/stub:$PATH" "$S/bbn-codex.sh" review --base
expect_code "status: --base without a value -> 2 (no endless loop)" 2 "$S/bbn-status.sh" --base
expect_code "status: base with shell characters refused" 2 "$S/bbn-status.sh" --base 'main;id'
mkdir -p "$T/norepo"
expect_code "codex: outside a git repo -> 2" 2 env GIT_CEILING_DIRECTORIES="$T" bash -c 'cd "$1" && exec "$2" review' _ "$T/norepo" "$S/bbn-codex.sh"
mkdir -p "$T/stub"
cat > "$T/stub/codex" <<'STUB'
#!/bin/sh
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
[ "${STUB_FAIL:-0}" = 1 ] && { echo boom >&2; exit 1; }
printf '%s\n' "$*" > "$out"
STUB
chmod +x "$T/stub/codex"
out="$(PATH="$T/stub:$PATH" "$S/bbn-codex.sh" run "add the thing" 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q -- '-s workspace-write' && echo "$out" | grep -q -- '-m gpt-6.1-sol' \
  && echo "$out" | grep -q 'model_reasoning_effort=xhigh' && echo "$out" | grep -q 'Do not commit, push' && echo "$out" | grep -q 'add the thing' \
  && ok "codex run: model, effort, sandbox and guard passed to the CLI" || bad "codex run (exit $rc)" "$out"
out="$(PATH="$T/stub:$PATH" BBN_CODEX_MODEL=m2 "$S/bbn-codex.sh" review --base main 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q -- '-s read-only' && echo "$out" | grep -q -- '-m m2' && echo "$out" | grep -q 'VERDICT: APPROVE' \
  && ok "codex review: read-only, env model override, asks for a VERDICT" || bad "codex review (exit $rc)" "$out"
expect_code "codex: CLI failure -> 1" 1 env PATH="$T/stub:$PATH" STUB_FAIL=1 "$S/bbn-codex.sh" run "x"
grep -q '"event":"codex","branch":"[^"]*","mode":"run","result":"fail"' "$(git rev-parse --git-common-dir)/bbn/runs.jsonl" \
  && ok "codex runs recorded in the ledger" || bad "codex ledger"
if command -v node >/dev/null 2>&1; then
  expect_code "run: unknown argument -> 2" 2 node "$S/bbn-run.mjs" --bogus
  expect_code "queue: base with shell characters refused" 2 node "$S/bbn-queue.mjs" --base 'x$(id)'
  expect_code "plan accept --by rejects unknown approver" 2 node "$S/bbn-plan.mjs" accept --by robot
fi

# --- exit codes documented for every script ---
for f in "$S"/*.sh "$S"/*.mjs; do
  n="$(basename "$f")"
  grep -q "$n" "$ROOT/docs/exit-codes.md" || bad "exit-codes.md misses $n"
done
ok "docs/exit-codes.md covers every script"

# --- shellcheck (only if installed) ---
if command -v shellcheck >/dev/null 2>&1; then
  out="$(cd "$S" && shellcheck -x ./*.sh lib/bbn-common.sh 2>&1)" && ok "shellcheck: scripts clean (all severities)" || bad "shellcheck scripts" "$out"
  out="$(cd "$S" && shellcheck -x -S warning ../tests/*.sh 2>&1)" && ok "shellcheck: tests clean (warning level)" || bad "shellcheck tests" "$out"
else
  ok "shellcheck not installed; skipped"
fi

echo "---"; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
