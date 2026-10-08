#!/usr/bin/env node
// Orca report from the run ledger: gates, reviews, merges, worktrees, and per-agent turn use vs budget.
// usage: orca-report.mjs [--since <ISO date>] [--json] [--strict]
// Exit: 0 ok, 1 --strict and a budget was exceeded or an agent run ended partial/failed, 2 usage
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { gitOk, commonDir, loadConfig } from './lib/orca-node.mjs';

const args = process.argv.slice(2);
if (!gitOk(['rev-parse', '--is-inside-work-tree'])) { console.error('[orca-report] not inside a git repo'); process.exit(2); }
const since = args.includes('--since') ? args[args.indexOf('--since') + 1] : '';
const file = join(commonDir(), 'runs.jsonl');
const events = (existsSync(file) ? readFileSync(file, 'utf8').split('\n') : [])
  .filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } })
  .filter((e) => e && (!since || e.ts >= since));
const cfg = loadConfig();
const budget = Object.fromEntries(Object.entries(cfg.budgets?.perRole || {}).map(([r, b]) => [r, b.maxTurns]));

const count = (ev, key) => events.filter((e) => e.event === ev).reduce((m, e) => (m[e[key]] = (m[e[key]] || 0) + 1, m), {});
const agents = {};
for (const e of events.filter((x) => x.event === 'agent')) {
  const a = agents[e.role] ||= { runs: 0, turns: 0, maxTurns: 0, partial: 0, failed: 0, overBudget: 0, budget: budget[e.role] ?? null };
  a.runs++; a.turns += e.turns || 0; a.maxTurns = Math.max(a.maxTurns, e.turns || 0);
  if (e.status === 'partial') a.partial++;
  if (e.status === 'failed') a.failed++;
  if (a.budget && e.turns > a.budget) a.overBudget++;
}
const summary = {
  ledger: file, since: since || null, events: events.length,
  worktrees: events.filter((e) => e.event === 'worktree.create').length,
  plans: { accepted: events.filter((e) => e.event === 'plan.accept').length, applied: events.filter((e) => e.event === 'plan.apply').length },
  gates: count('gate', 'result'), reviews: count('review', 'verdict'), merges: count('merge', 'result'),
  cleanupRemoved: events.filter((e) => e.event === 'cleanup').reduce((n, e) => n + (e.removed || 0), 0),
  agents,
};
const issues = Object.entries(agents).flatMap(([r, a]) => [
  ...(a.overBudget ? [`${r}: ${a.overBudget} run(s) over the ${a.budget}-turn budget`] : []),
  ...(a.partial ? [`${r}: ${a.partial} run(s) stopped at the turn limit (partial)`] : []),
  ...(a.failed ? [`${r}: ${a.failed} failed run(s)`] : []),
]);
summary.issues = issues;

if (args.includes('--json')) console.log(JSON.stringify(summary, null, 2));
else {
  const kv = (o) => Object.entries(o).map(([k, v]) => `${k} ${v}`).join(', ') || '-';
  console.log(`Orca report (${events.length} events${since ? ' since ' + since : ''})`);
  console.log(`plans: accepted ${summary.plans.accepted}, applied ${summary.plans.applied}; worktrees created ${summary.worktrees}; cleaned up ${summary.cleanupRemoved}`);
  console.log(`gates: ${kv(summary.gates)}`);
  console.log(`reviews: ${kv(summary.reviews)}`);
  console.log(`merges: ${kv(summary.merges)}`);
  console.log('agents (turns used / budget):');
  if (!Object.keys(agents).length) console.log('  none recorded (Orca records runs with orca-ledger.sh agent ...)');
  for (const [r, a] of Object.entries(agents))
    console.log(`  ${r.padEnd(18)} runs ${a.runs}, turns ${a.turns}, max ${a.maxTurns}/${a.budget ?? '?'}${a.partial ? ', partial ' + a.partial : ''}${a.failed ? ', failed ' + a.failed : ''}`);
  for (const i of issues) console.log(`! ${i}`);
}
if (args.includes('--strict') && issues.length) process.exit(1);
