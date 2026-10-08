#!/usr/bin/env node
// Orca merge queue with conflict pre-detection (git merge-tree, no checkout, nothing written).
// Order: plan dependsOn first, then ready (gate pass + current APPROVE), then fewest predicted
// conflicts, fewest overlapping files, smallest diff.
// usage: orca-queue.mjs [--base <ref>] [--json]      Exit: 0 ok, 2 usage/not a repo
import { execSync } from 'node:child_process';
import { join } from 'node:path';
import { git, gitOk, readJson, pickBase, worktrees, PROTECTED } from './lib/orca-node.mjs';

const args = process.argv.slice(2);
const baseArg = args.includes('--base') ? args[args.indexOf('--base') + 1] : undefined;
if (!gitOk(['rev-parse', '--is-inside-work-tree'])) { console.error('[orca-queue] not inside a git repo'); process.exit(2); }
let base; try { base = pickBase(baseArg); } catch (e) { console.error(`[orca-queue] ${e.message}`); process.exit(2); }

const wts = worktrees();
const plan = readJson(join(wts[0].path, '.orca', 'plan.json'));
const deps = new Map((plan?.streams || []).map((s) => [`feature/${s.slug}`, (s.dependsOn || []).map((d) => `feature/${d}`)]));

function mergeTree(a, b) {   // -> list of conflicted files ([] = clean)
  const r = git(['merge-tree', '--write-tree', '--name-only', '--no-messages', a, b], { allowFail: true });
  if (typeof r === 'string') return [];
  if (r.code === 1) return r.out.split('\n').slice(1).filter(Boolean);
  return [`(merge-tree failed: exit ${r.code})`];
}
const patchId = (mb, head) => execSync(`git diff ${mb} ${head} | git patch-id --stable`, { encoding: 'utf8' }).split(' ')[0].trim();

const items = [];
for (const w of wts.slice(1)) {
  if (!w.branch || PROTECTED.has(w.branch)) continue;
  const head = git(['rev-parse', w.branch]);
  const mb = git(['merge-base', base, head]);
  const files = git(['diff', '--name-only', mb, head]).split('\n').filter(Boolean);
  const lines = git(['diff', '--numstat', mb, head]).split('\n').filter(Boolean)
    .reduce((n, l) => n + l.split('\t').slice(0, 2).reduce((a, x) => a + (Number(x) || 0), 0), 0);
  const sd = join(git(['-C', w.path, 'rev-parse', '--absolute-git-dir']), 'orca');
  const gate = readJson(join(sd, 'gate.json'), {});
  const review = readJson(join(sd, 'review.json'), {});
  const gateOk = gate.result === 'pass' && gate.head === head;
  const reviewOk = review.verdict === 'APPROVE' && review.patch_id === patchId(mb, head);
  const [behind, ahead] = git(['rev-list', '--left-right', '--count', `${base}...${head}`]).split(/\s+/).map(Number);
  items.push({ branch: w.branch, worktree: w.path, head: head.slice(0, 7), ahead, behind, files, lines,
    gate: gate.result ? (gate.head === head ? gate.result : gate.result + '*') : '-',
    review: review.verdict ? (reviewOk ? review.verdict : review.verdict + '*') : '-',
    gateOk, reviewOk, ready: gateOk && reviewOk, baseConflicts: mergeTree(base, head), pairConflicts: {}, overlaps: 0,
    dependsOn: (deps.get(w.branch) || []) });
}
for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
  const a = items[i], b = items[j];
  const shared = a.files.filter((f) => b.files.includes(f));
  if (!shared.length) continue;
  a.overlaps += shared.length; b.overlaps += shared.length;
  const c = mergeTree(a.branch, b.branch);
  if (c.length) { a.pairConflicts[b.branch] = c; b.pairConflicts[a.branch] = c; }
}

// Queue: repeatedly take the best item whose in-queue dependencies are already placed.
const score = (x) => [x.ready ? 0 : 1, x.baseConflicts.length, Object.keys(x.pairConflicts).length, x.overlaps, x.lines, x.branch];
const cmp = (a, b) => { const x = score(a), y = score(b); for (let k = 0; k < x.length; k++) if (x[k] !== y[k]) return x[k] < y[k] ? -1 : 1; return 0; };
const names = new Set(items.map((x) => x.branch));
const placed = new Set(); const queue = []; let left = [...items];
while (left.length) {
  const avail = left.filter((x) => x.dependsOn.every((d) => !names.has(d) || placed.has(d)));
  const next = (avail.length ? avail : left).sort(cmp)[0];   // cycle guard: fall back to best overall
  queue.push(next); placed.add(next.branch); left = left.filter((x) => x !== next);
}

if (args.includes('--json')) { console.log(JSON.stringify({ base, queue }, null, 2)); process.exit(0); }
console.log(`base: ${base}`);
if (!queue.length) { console.log('no feature worktrees'); process.exit(0); }
const pad = (s, n) => String(s).padEnd(n);
console.log(pad('#', 3) + pad('BRANCH', 30) + pad('READY', 7) + pad('GATE', 7) + pad('REVIEW', 10) + pad('+/-', 9) + pad('LINES', 7) + pad('OVERLAP', 8) + 'CONFLICTS');
queue.forEach((x, i) => {
  const c = [x.baseConflicts.length ? `base:${x.baseConflicts.length}` : '', ...Object.keys(x.pairConflicts).map((b) => b.replace('feature/', '') + ':' + x.pairConflicts[b].length)].filter(Boolean).join(' ') || '-';
  console.log(pad(i + 1, 3) + pad(x.branch, 30) + pad(x.ready ? 'yes' : 'no', 7) + pad(x.gate, 7) + pad(x.review, 10) + pad(`+${x.ahead}/-${x.behind}`, 9) + pad(x.lines, 7) + pad(x.overlaps, 8) + c);
});
console.log('(* = recorded for an older commit or different changes)');
const first = queue[0];
console.log(first.ready ? `next: ${first.branch} -> /orca-merge --apply` : `next: ${first.branch} needs ${[first.gateOk ? '' : 'a passing gate', first.reviewOk ? '' : 'a current APPROVE'].filter(Boolean).join(' and ')} (/orca-review)`);
for (const x of queue) {
  if (x.baseConflicts.length) console.log(`! ${x.branch} conflicts with ${base} in ${x.baseConflicts.join(', ')}: merge will stop at rebase; codex resolves, then re-review`);
  for (const [b, f] of Object.entries(x.pairConflicts))
    if (queue.indexOf(x) < queue.findIndex((y) => y.branch === b))
      console.log(`! ${x.branch} and ${b} conflict in ${f.join(', ')}: merge ${x.branch} first; ${b} will need codex + re-review`);
}
