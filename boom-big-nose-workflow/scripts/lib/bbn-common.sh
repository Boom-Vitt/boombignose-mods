# shellcheck shell=bash
# Shared helpers for BBN scripts. Bash 3.2 compatible (macOS /bin/bash).

bbn_log()  { printf '[%s] %s\n' "${BBN_TAG:-bbn}" "$*"; }
bbn_warn() { printf '[%s] WARN: %s\n' "${BBN_TAG:-bbn}" "$*" >&2; }
bbn_die()  { printf '[%s] ERROR: %s\n' "${BBN_TAG:-bbn}" "$1" >&2; exit "${2:-1}"; }

bbn_require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || bbn_die "not inside a git repo"
}

# Per-worktree state lives inside the worktree's own git dir, never in the work tree.
bbn_state_dir() {
  local d
  d="$(git rev-parse --absolute-git-dir)/bbn"
  mkdir -p "$d"
  printf '%s' "$d"
}

# Base branch: --base / BBN_BASE, else first existing of origin/dev origin/main dev main master.
bbn_pick_base() {
  local override="${1:-${BBN_BASE:-}}" ref
  if [ -n "$override" ]; then
    git rev-parse --verify --quiet "$override" >/dev/null || bbn_die "base '$override' not found"
    printf '%s' "$override"; return
  fi
  for ref in origin/dev origin/main dev main master; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then printf '%s' "$ref"; return; fi
  done
  bbn_die "no base branch found (tried origin/dev origin/main dev main master)"
}

# Stable fingerprint of the branch's changes relative to base (ignores line numbers),
# so a review survives a clean rebase but not a content change.
bbn_patch_id() {
  local base="$1" mb
  mb="$(git merge-base "$base" HEAD)" || return 1
  git diff "$mb" HEAD | git patch-id --stable | awk '{print $1}'
}

bbn_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Read a flat "key": "value" string from our own one-key-per-line JSON files.
bbn_json_get() {
  [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]]*\"$2\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$1" | head -n 1
}

bbn_json_escape() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

bbn_is_clean() {  # tracked changes only; untracked files do not block
  [ -z "$(git -C "${1:-.}" status --porcelain --untracked-files=no)" ]
}

bbn_protected_branch() {
  case "$1" in main|master|dev|develop|HEAD) return 0 ;; *) return 1 ;; esac
}

# Never let git block on a credential prompt inside an agent run.
export GIT_TERMINAL_PROMPT=0

# Repo-wide BBN dir shared by all worktrees (<common-git-dir>/bbn).
bbn_common_dir() {
  local c
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || c="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
  mkdir -p "$c/bbn"
  printf '%s' "$c/bbn"
}

# Append one JSON line to the run ledger: bbn_ledger <event> [key=value ...]
# Values are strings unless they are plain integers. Disabled with BBN_LEDGER=0.
bbn_ledger() {
  [ "${BBN_LEDGER:-1}" = 0 ] && return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  local ev="$1" kv k v line br
  shift
  br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  line="{\"ts\":\"$(bbn_now)\",\"event\":\"$(bbn_json_escape "$ev")\",\"branch\":\"$(bbn_json_escape "$br")\""
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    case "$v" in
      ''|*[!0-9]*) line="$line,\"$k\":\"$(bbn_json_escape "$v")\"" ;;
      *) line="$line,\"$k\":$v" ;;
    esac
  done
  printf '%s}\n' "$line" >> "$(bbn_common_dir)/runs.jsonl"
}

# Run a command with a time limit (portable; no coreutils timeout on macOS).
# Returns the command's exit code, or 124 on timeout.
bbn_run_timeout() {
  local ticks=$(( $1 * 5 )) pid i=0 rc
  shift
  "$@" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge "$ticks" ]; then
      kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 0.2; i=$((i + 1))
  done
  wait "$pid"; rc=$?
  return "$rc"
}

# Integer from the plugin's bbn.config.json: bbn_cfg_int <key> <default>
bbn_cfg_int() {
  local cfg v
  cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bbn.config.json"
  v="$(sed -n "s/.*\"$1\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$cfg" 2>/dev/null | head -n 1)"
  printf '%s' "${v:-$2}"
}
