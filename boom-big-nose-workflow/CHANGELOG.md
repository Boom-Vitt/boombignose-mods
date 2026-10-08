# Changelog - boom-big-nose-workflow

Based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); [SemVer](https://semver.org/). The repository-wide CHANGELOG.md summarises each release in Thai and English and links here.

## Unreleased

- **Changed (breaking)** The workflow is now named BBN everywhere: commands `/bbn-*`, agents `bbn-orchestrator` and `bbn-reviewer`, skills `bbn-workflow` and `bbn-architecture`, scripts `scripts/bbn-*`, `bbn.config.json`, `bbn.plan.schema.json`, environment variables `BBN_*`, the gate template `templates/github/bbn-gate.yml`, and state in `.bbn/` and `<common-git-dir>/bbn/`.
- **Added** `docs/workflow-diagram.md`: the whole workflow (plan, build, queue, review, merge, cleanup) as one diagram.
- **Added** Codex support: `.codex-plugin/plugin.json` and a Codex marketplace (`.agents/plugins/marketplace.json` at the repository root), so `codex plugin marketplace add Boom-Vitt/boombignose-mods` then `codex plugin add boom-big-nose-workflow@boombignose-mods` installs the skills and both MCP servers. The `bbn-workflow` skill explains how to run each step in Codex: `${CLAUDE_PLUGIN_ROOT}` path, `commands/bbn-<step>.md` in place of slash commands, an independent reviewer and `codex mcp login perplexity`.
- **Added** SDLC phases (requirements, design, build, test and review, release, maintain), each with an exit criterion, and the principles behind them, in the `bbn-workflow` skill, the orchestrator's loop and `docs/workflow-diagram.md` (English and Thai).

## 0.4.0 - 2026-10-08

- **Added** `/bbn-plan` + `scripts/bbn-plan.mjs` + `bbn.plan.schema.json`: the plan checkpoint is a file (`.bbn/plan.json`, git-excluded). `check` validates schema, stream budget, acceptance checks, relative paths, dependencies (no cycles) and file ownership (two streams may share a path only if one depends on the other). `accept` records a hash; `apply --apply` refuses an unaccepted or changed plan and creates worktrees in dependency order with ownership maps. See ADR-0003.
- **Added** `/bbn-queue` + `scripts/bbn-queue.mjs`: merge order by plan dependencies, readiness, conflicts predicted with `git merge-tree` (against base and between branches), overlaps and size. Read-only.
- **Added** run ledger `<common-git-dir>/bbn/runs.jsonl` (gate, review, merge, worktree, plan, cleanup events), `scripts/bbn-ledger.sh agent <role> --turns N`, and `/bbn-report` + `scripts/bbn-report.mjs` (turns per agent vs `maxTurns`, `--strict`, `--json`). `BBN_LEDGER=0` disables it.
- **Added** `tests/smoke.sh`: dry-run end-to-end test in a temp repo (plan -> worktrees -> gate -> review -> queue -> ordered merge -> report -> cleanup), no network.
- **Added** `docs/QUICKSTART.md` (Thai) and `docs/QUICKSTART.en.md`; `docs/exit-codes.md`; ADR-0003.
- **Changed** `bbn-merge.sh --apply` refuses (exit 3) a branch whose plan dependencies are not merged; `--ignore-order` overrides.
- **Changed** `bbn-gate.sh` limits each step to `reviewGate.stepTimeoutSec` (1800 s; `BBN_GATE_TIMEOUT`); a timed-out step fails the gate.
- **Changed** `/bbn-doctor` prints a `fix:` hint for every WARN/FAIL, fails if `.mcp.json` sends an Authorization header (401 regression guard), bounds `claude mcp list` with a timeout, warns on git older than 2.38, and shows plan and ledger state.
- **Changed** `bbn-config-check.mjs` uses a shared schema validator and fails on a `tools:` allowlist in any agent.
- **Fixed** `worktree-new.sh` created feature branches tracking `origin/<base>`, so `bbn-cleanup.sh --delete-branches` could not delete them after a local merge. Branches are now created with `--no-track`.
- **Changed** all scripts are shellcheck-clean; `GIT_TERMINAL_PROMPT=0` so git never waits for credentials.

## 0.3.0 - 2026-10-08

- **Fixed** Perplexity MCP returned HTTP 401: the plugin sent `Authorization: Bearer ${PERPLEXITY_API_KEY}` with the variable unset, and a set Authorization header disables OAuth. The plugin now uses Perplexity sign-in (`/mcp`); the API-key route is documented as opt-in.
- **Fixed** role agents could not reach any MCP tool (`tools:` allowlist). They now use `disallowedTools`; read-only roles deny Write/Edit/NotebookEdit.
- **Fixed** `codex` used an invalid colour (`magenta` -> `purple`).
- **Fixed** `bbn-merge.sh` ran the gate before rebasing and checked out the base inside the feature worktree. Now rebase -> gate -> review fingerprint -> merge in the base worktree; never pushes the base.
- **Added** `maxTurns` per agent (budget enforcement), checked against `bbn.config.json`.
- **Added** graceful fallback: Perplexity/Context7 optional; agents use WebSearch/WebFetch.
- **Added** `/bbn-doctor`, `/bbn-status`, `/bbn-cleanup`; `bbn-review-record.sh` (verdict bound to `git patch-id`); `bbn-merge.sh --pr` (draft PR via `gh`).
- **Added** `bbn.config.schema.json` + `scripts/bbn-config-check.mjs`; `templates/github/bbn-gate.yml`; `tests/run.sh`.
- **Changed** gate/review state moved from the work tree to `<git-dir>/bbn/`; `worktree-new.sh` validates slugs, enforces `maxParallelWorktrees`, and excludes `.env.worktree` and `.bbn/` from git.

## 0.2.0 - 2026-10-08

- **Added** `bbn-reviewer` agent, `/bbn-review`, `/bbn-merge`, `bbn-gate.sh`, `bbn-merge.sh`, `bbn.config.json`, ADRs, worktree isolation.

## 0.1.0 - 2026-10-08

- **Added** first version: BBN hub + Grok Build / Claude Code / Codex roles, git worktree skill, Context7 + Perplexity MCP.
