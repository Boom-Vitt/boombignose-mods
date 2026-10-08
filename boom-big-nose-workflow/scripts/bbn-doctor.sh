#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN doctor: health check with fix hints. Never prints secret values (presence only).
# usage: bbn-doctor.sh [--offline]
#   --offline or BBN_DOCTOR_OFFLINE=1 skips `claude mcp list`; BBN_DOCTOR_MCP_TIMEOUT (default 60s) bounds it.
# Exit: 0 no FAIL (WARNs allowed), 1 at least one FAIL
set -uo pipefail
BBN_TAG=bbn-doctor
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/lib/bbn-common.sh"
OFFLINE="${BBN_DOCTOR_OFFLINE:-0}"; [ "${1:-}" = "--offline" ] && OFFLINE=1
fails=0; warns=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
fix()  { printf '        fix: %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "tools"
if have git; then
  gv="$(git --version | awk '{print $3}')"
  # /bbn-queue needs `git merge-tree --write-tree` (git 2.38+)
  if printf '%s\n' "$gv" | awk -F. '{exit !($1 > 2 || ($1 == 2 && $2 >= 38))}'; then ok "git $gv"
  else warn "git $gv is older than 2.38: /bbn-queue cannot predict conflicts"; fix "brew install git"; fi
else fail "git not found"; fix "install git (xcode-select --install or brew install git)"; fi
if have gh; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh not authenticated (only /bbn-merge --pr needs it)"; fix "gh auth login"; fi
else warn "gh not installed (only /bbn-merge --pr needs it)"; fix "brew install gh"; fi
if have claude; then ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"; else warn "claude CLI not on PATH"; fi
if have node; then ok "node $(node --version)"; else warn "node not found: config check, /bbn-plan, /bbn-queue, /bbn-report need it"; fix "brew install node"; fi
if have shellcheck; then ok "shellcheck $(shellcheck --version | awk '/^version/{print $2}')"; else ok "shellcheck not installed (optional, for development)"; fi

echo "plugin"
ok "root $ROOT"
missing=0
for s in bbn-gate.sh bbn-merge.sh bbn-review-record.sh bbn-status.sh bbn-cleanup.sh bbn-ledger.sh worktree-new.sh bbn-plan.mjs bbn-queue.mjs bbn-report.mjs; do
  [ -x "$HERE/$s" ] || { fail "scripts/$s missing or not executable"; missing=1; }
done
if [ "$missing" -eq 1 ]; then fix "chmod +x \"$HERE\"/*.sh \"$HERE\"/*.mjs"; else ok "scripts executable"; fi
if have node; then
  if out="$(node "$HERE/bbn-config-check.mjs" 2>&1)"; then ok "$out"; else fail "config invalid"; printf '%s\n' "$out" | while IFS= read -r l; do echo "        $l"; done; fi
fi
# Regression guard for the v0.1-v0.2 Perplexity 401: no Authorization header in the plugin's .mcp.json.
if grep -qi 'authorization' "$ROOT/.mcp.json"; then
  fail ".mcp.json sends an Authorization header (empty key -> 401, and it disables sign-in)"; fix "remove the headers block; use /mcp sign-in or a separate perplexity-key server (README)"
else ok ".mcp.json has no Authorization header (sign-in path)"; fi

echo "keys (presence only)"
if [ -n "${PERPLEXITY_API_KEY:-}" ]; then ok "PERPLEXITY_API_KEY set (used only by a perplexity-key server, if you added one)"
else ok "PERPLEXITY_API_KEY not set (fine: the plugin uses Perplexity sign-in)"; fi
if [ -n "${CONTEXT7_API_KEY:-}" ]; then ok "CONTEXT7_API_KEY set"; else ok "CONTEXT7_API_KEY not set (optional)"; fi

echo "mcp"
if [ "$OFFLINE" = 1 ] || ! have claude; then
  ok "skipped (offline)"
else
  tmp="$(mktemp "${TMPDIR:-/tmp}/bbn-doctor.XXXXXX")"
  # shellcheck disable=SC2016  # $1 is expanded by the inner sh, on purpose
  bbn_run_timeout "${BBN_DOCTOR_MCP_TIMEOUT:-60}" sh -c 'claude mcp list > "$1" 2>&1' _ "$tmp"; rc=$?
  if [ "$rc" -eq 124 ]; then
    warn "claude mcp list timed out after ${BBN_DOCTOR_MCP_TIMEOUT:-60}s; agents use WebSearch/WebFetch fallbacks"; fix "re-run later or raise BBN_DOCTOR_MCP_TIMEOUT"
  else
    c7="$(grep 'boom-big-nose-workflow:context7' "$tmp" || true)"
    px="$(grep 'boom-big-nose-workflow:perplexity' "$tmp" || true)"
    pk="$(grep -E '^perplexity-key:' "$tmp" || true)"
    case "$c7" in
      *Connected*) ok "context7 connected" ;;
      "") warn "context7 not listed: plugin disabled? (fallback: WebFetch of official docs)"; fix "claude plugin enable boom-big-nose-workflow@boombignose-mods" ;;
      *) warn "context7: ${c7##* - } (fallback: WebFetch of official docs)"; fix "check network; Context7 needs no key" ;;
    esac
    case "$px" in
      *Connected*) ok "perplexity connected (sign-in)" ;;
      *"Needs authentication"*)
        if [ -n "$pk" ] && echo "$pk" | grep -q Connected; then ok "perplexity via perplexity-key server (plugin sign-in not needed)"
        else warn "perplexity not signed in (fallback: WebSearch + WebFetch)"; fix "in Claude Code: /mcp -> plugin:boom-big-nose-workflow:perplexity -> sign in"; fi ;;
      *401*|*Failed*) fail "perplexity failed: ${px##* - }"; fix "a key/header is being sent; see README 'Perplexity'" ;;
      "") warn "perplexity not listed (fallback: WebSearch + WebFetch)" ;;
      *) warn "perplexity: ${px##* - } (fallback: WebSearch + WebFetch)" ;;
    esac
    if [ -n "$pk" ]; then
      if echo "$pk" | grep -q Connected; then ok "perplexity-key connected"; else warn "perplexity-key: ${pk##* - }"; fi
    fi
  fi
  rm -f "$tmp"
fi

echo "repo"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "in $(git rev-parse --show-toplevel)"
  git worktree list | sed 's/^/        /'
  main_wt="$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')"
  if [ -f "$main_wt/.bbn/plan.json" ]; then
    st="$(sed -n 's/^[[:space:]]*"status":[[:space:]]*"\([a-z]*\)".*/\1/p' "$main_wt/.bbn/plan.json" | head -n 1)"
    ok "plan: .bbn/plan.json ($st)"
  else ok "plan: none (/bbn-plan to create one)"; fi
  led="$(bbn_common_dir)/runs.jsonl"
  if [ -f "$led" ]; then ok "ledger: $(wc -l < "$led" | tr -d ' ') event(s)"; else ok "ledger: empty"; fi
else ok "not in a git repo (worktree checks skipped)"; fi

echo "result: $fails fail, $warns warn"
[ "$fails" -eq 0 ]
