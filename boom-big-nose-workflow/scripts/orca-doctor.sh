#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Orca doctor: health check with fix hints. Never prints secret values (presence only).
# usage: orca-doctor.sh [--offline]
#   --offline or ORCA_DOCTOR_OFFLINE=1 skips `claude mcp list`; ORCA_DOCTOR_MCP_TIMEOUT (default 60s) bounds it.
# Exit: 0 no FAIL (WARNs allowed), 1 at least one FAIL
set -uo pipefail
ORCA_TAG=orca-doctor
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/lib/orca-common.sh"
OFFLINE="${ORCA_DOCTOR_OFFLINE:-0}"; [ "${1:-}" = "--offline" ] && OFFLINE=1
fails=0; warns=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; warns=$((warns + 1)); }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }
fix()  { printf '        fix: %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "tools"
if have git; then
  gv="$(git --version | awk '{print $3}')"
  # /orca-queue needs `git merge-tree --write-tree` (git 2.38+)
  if printf '%s\n' "$gv" | awk -F. '{exit !($1 > 2 || ($1 == 2 && $2 >= 38))}'; then ok "git $gv"
  else warn "git $gv is older than 2.38: /orca-queue cannot predict conflicts"; fix "brew install git"; fi
else fail "git not found"; fix "install git (xcode-select --install or brew install git)"; fi
if have gh; then
  if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh not authenticated (only /orca-merge --pr needs it)"; fix "gh auth login"; fi
else warn "gh not installed (only /orca-merge --pr needs it)"; fix "brew install gh"; fi
if have claude; then ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"; else warn "claude CLI not on PATH"; fi
if have node; then ok "node $(node --version)"; else warn "node not found: config check, /orca-plan, /orca-queue, /orca-report need it"; fix "brew install node"; fi
if have shellcheck; then ok "shellcheck $(shellcheck --version | awk '/^version/{print $2}')"; else ok "shellcheck not installed (optional, for development)"; fi

echo "plugin"
ok "root $ROOT"
missing=0
for s in orca-gate.sh orca-merge.sh orca-review-record.sh orca-status.sh orca-cleanup.sh orca-ledger.sh worktree-new.sh orca-plan.mjs orca-queue.mjs orca-report.mjs; do
  [ -x "$HERE/$s" ] || { fail "scripts/$s missing or not executable"; missing=1; }
done
if [ "$missing" -eq 1 ]; then fix "chmod +x \"$HERE\"/*.sh \"$HERE\"/*.mjs"; else ok "scripts executable"; fi
if have node; then
  if out="$(node "$HERE/orca-config-check.mjs" 2>&1)"; then ok "$out"; else fail "config invalid"; printf '%s\n' "$out" | while IFS= read -r l; do echo "        $l"; done; fi
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
  tmp="$(mktemp "${TMPDIR:-/tmp}/orca-doctor.XXXXXX")"
  # shellcheck disable=SC2016  # $1 is expanded by the inner sh, on purpose
  orca_run_timeout "${ORCA_DOCTOR_MCP_TIMEOUT:-60}" sh -c 'claude mcp list > "$1" 2>&1' _ "$tmp"; rc=$?
  if [ "$rc" -eq 124 ]; then
    warn "claude mcp list timed out after ${ORCA_DOCTOR_MCP_TIMEOUT:-60}s; agents use WebSearch/WebFetch fallbacks"; fix "re-run later or raise ORCA_DOCTOR_MCP_TIMEOUT"
  else
    c7="$(grep 'boom-big-nose-workflow:context7' "$tmp" || true)"
    px="$(grep 'boom-big-nose-workflow:perplexity' "$tmp" || true)"
    pk="$(grep -E '^perplexity-key:' "$tmp" || true)"
    case "$c7" in
      *Connected*) ok "context7 connected" ;;
      "") warn "context7 not listed: plugin disabled? (fallback: WebFetch of official docs)"; fix "claude plugin enable boom-big-nose-workflow@claude-mods-boombignose" ;;
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
  if [ -f "$main_wt/.orca/plan.json" ]; then
    st="$(sed -n 's/^[[:space:]]*"status":[[:space:]]*"\([a-z]*\)".*/\1/p' "$main_wt/.orca/plan.json" | head -n 1)"
    ok "plan: .orca/plan.json ($st)"
  else ok "plan: none (/orca-plan to create one)"; fi
  led="$(orca_common_dir)/runs.jsonl"
  if [ -f "$led" ]; then ok "ledger: $(wc -l < "$led" | tr -d ' ') event(s)"; else ok "ledger: empty"; fi
else ok "not in a git repo (worktree checks skipped)"; fi

echo "result: $fails fail, $warns warn"
[ "$fails" -eq 0 ]
