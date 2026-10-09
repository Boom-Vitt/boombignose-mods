#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# BBN status: every worktree with branch, ahead/behind base, dirty, gate and review state,
# plus files touched by more than one feature branch (merge-conflict risk).
# usage: bbn-status.sh [--base <ref>]
set -uo pipefail
BBN_TAG=bbn-status
. "$(cd "$(dirname "$0")" && pwd)/lib/bbn-common.sh"
BASE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in --base) bbn_need_val "$@"; BASE_ARG="$2"; shift 2 ;; -h|--help) sed -n '2,4p' "$0"; exit 0 ;; *) bbn_die "unknown arg: $1" 2 ;; esac
done
bbn_require_repo
base="$(bbn_pick_base "$BASE_ARG")" || exit
echo "base: $base ($(git rev-parse --short "$base"))"
printf '%-34s %-10s %-9s %-6s %-14s %s\n' BRANCH AHEAD/BEH DIRTY GATE REVIEW WORKTREE

tmp="$(mktemp "${TMPDIR:-/tmp}/bbn-status.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch /{sub("refs/heads/","",$2); print p "\t" $2} /^detached/{print p "\t(detached)"}' |
while IFS="$(printf '\t')" read -r wt br; do
  [ -d "$wt" ] || continue
  head="$(git -C "$wt" rev-parse HEAD)"
  ab="-"
  if [ "$br" != "(detached)" ]; then
    lr="$(git rev-list --left-right --count "$base...$head" 2>/dev/null)"
    behind="${lr%%[[:space:]]*}"; ahead="${lr##*[[:space:]]}"
    ab="+${ahead:-0}/-${behind:-0}"
  fi
  dirty=no; bbn_is_clean "$wt" || dirty=yes
  sd="$(git -C "$wt" rev-parse --absolute-git-dir)/bbn"
  gate="$(bbn_json_get "$sd/gate.json" result)"; gh="$(bbn_json_get "$sd/gate.json" head)"
  [ -n "$gate" ] && [ "$gh" != "$head" ] && gate="$gate*"
  rv="$(bbn_json_get "$sd/review.json" verdict)"; rh="$(bbn_json_get "$sd/review.json" head)"
  [ -n "$rv" ] && [ "$rh" != "$head" ] && rv="$rv*"
  printf '%-34s %-10s %-9s %-6s %-14s %s\n' "$br" "$ab" "$dirty" "${gate:--}" "${rv:--}" "$wt"
  if ! bbn_protected_branch "$br" && [ "$br" != "(detached)" ]; then
    mb="$(git merge-base "$base" "$head" 2>/dev/null)" && \
      git diff --name-only "$mb" "$head" | sed "s|^|$br	|" >> "$tmp"
  fi
done
echo "(* = recorded for an older commit; re-run gate/review)"

overlap="$(cut -f2 "$tmp" | sort | uniq -d)"
if [ -n "$overlap" ]; then
  echo "conflict risk - files changed on more than one feature branch:"
  echo "$overlap" | while read -r f; do
    printf '  %s <- %s\n' "$f" "$(awk -F'\t' -v f="$f" '$2==f{print $1}' "$tmp" | sort -u | tr '\n' ' ')"
  done
  echo "  merge order: smallest/most-depended-on first; codex resolves the later ones; re-gate each."
else
  echo "no overlapping files between feature branches"
fi
