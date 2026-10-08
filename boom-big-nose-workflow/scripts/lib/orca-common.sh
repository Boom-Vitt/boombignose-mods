# shellcheck shell=bash
# Shared helpers for Orca scripts. Bash 3.2 compatible (macOS /bin/bash).

orca_log()  { printf '[%s] %s\n' "${ORCA_TAG:-orca}" "$*"; }
orca_warn() { printf '[%s] WARN: %s\n' "${ORCA_TAG:-orca}" "$*" >&2; }
orca_die()  { printf '[%s] ERROR: %s\n' "${ORCA_TAG:-orca}" "$1" >&2; exit "${2:-1}"; }

orca_require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || orca_die "not inside a git repo"
}

# Per-worktree state lives inside the worktree's own git dir, never in the work tree.
orca_state_dir() {
  local d
  d="$(git rev-parse --absolute-git-dir)/orca"
  mkdir -p "$d"
  printf '%s' "$d"
}

# Base branch: --base / ORCA_BASE, else first existing of origin/dev origin/main dev main master.
orca_pick_base() {
  local override="${1:-${ORCA_BASE:-}}" ref
  if [ -n "$override" ]; then
    git rev-parse --verify --quiet "$override" >/dev/null || orca_die "base '$override' not found"
    printf '%s' "$override"; return
  fi
  for ref in origin/dev origin/main dev main master; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then printf '%s' "$ref"; return; fi
  done
  orca_die "no base branch found (tried origin/dev origin/main dev main master)"
}

# Stable fingerprint of the branch's changes relative to base (ignores line numbers),
# so a review survives a clean rebase but not a content change.
orca_patch_id() {
  local base="$1" mb
  mb="$(git merge-base "$base" HEAD)" || return 1
  git diff "$mb" HEAD | git patch-id --stable | awk '{print $1}'
}

orca_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Read a flat "key": "value" string from our own one-key-per-line JSON files.
orca_json_get() {
  [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]]*\"$2\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$1" | head -n 1
}

orca_json_escape() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

orca_is_clean() {  # tracked changes only; untracked files do not block
  [ -z "$(git -C "${1:-.}" status --porcelain --untracked-files=no)" ]
}

orca_protected_branch() {
  case "$1" in main|master|dev|develop|HEAD) return 0 ;; *) return 1 ;; esac
}

# Never let git block on a credential prompt inside an agent run.
export GIT_TERMINAL_PROMPT=0

# Repo-wide Orca dir shared by all worktrees (<common-git-dir>/orca).
orca_common_dir() {
  local c
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || c="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
  mkdir -p "$c/orca"
  printf '%s' "$c/orca"
}

# Append one JSON line to the run ledger: orca_ledger <event> [key=value ...]
# Values are strings unless they are plain integers. Disabled with ORCA_LEDGER=0.
orca_ledger() {
  [ "${ORCA_LEDGER:-1}" = 0 ] && return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  local ev="$1" kv k v line br
  shift
  br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  line="{\"ts\":\"$(orca_now)\",\"event\":\"$(orca_json_escape "$ev")\",\"branch\":\"$(orca_json_escape "$br")\""
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    case "$v" in
      ''|*[!0-9]*) line="$line,\"$k\":\"$(orca_json_escape "$v")\"" ;;
      *) line="$line,\"$k\":$v" ;;
    esac
  done
  printf '%s}\n' "$line" >> "$(orca_common_dir)/runs.jsonl"
}

# Run a command with a time limit (portable; no coreutils timeout on macOS).
# Returns the command's exit code, or 124 on timeout.
orca_run_timeout() {
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

# Integer from the plugin's orca.config.json: orca_cfg_int <key> <default>
orca_cfg_int() {
  local cfg v
  cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/orca.config.json"
  v="$(sed -n "s/.*\"$1\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$cfg" 2>/dev/null | head -n 1)"
  printf '%s' "${v:-$2}"
}
