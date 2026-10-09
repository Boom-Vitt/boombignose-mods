// Shared helpers for the BBN Node scripts (no dependencies).
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { appendFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const PLUGIN_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const SLUG_RE = /^[a-z0-9][a-z0-9._-]{0,59}$/;
export const PROTECTED = new Set(['main', 'master', 'dev', 'develop', 'HEAD']);
export const BASE_CANDIDATES = ['origin/dev', 'origin/main', 'dev', 'main', 'master'];

export function git(args, opts = {}) {
  try {
    return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0' }, ...opts }).trim();
  } catch (e) {
    if (opts.allowFail) return { code: e.status, out: String(e.stdout || '').trim() };
    throw e;
  }
}
export const gitOk = (args, opts = {}) => {
  try { git(args, opts); return true; } catch { return false; }
};
export function readJson(p, fallback = null) {
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return fallback; }
}
export function loadConfig() { return readJson(join(PLUGIN_ROOT, 'bbn.config.json'), {}); }

export function pickBase(override) {
  if (override) {
    if (!/^[\w./-]+$/.test(override)) throw new Error(`base '${override}' must be a plain branch name`);
    if (!gitOk(['rev-parse', '--verify', '--quiet', override])) throw new Error(`base '${override}' not found`);
    return override;
  }
  for (const r of BASE_CANDIDATES) if (gitOk(['rev-parse', '--verify', '--quiet', r])) return r;
  throw new Error('no base branch found');
}
export function commonDir() {
  const d = join(git(['rev-parse', '--path-format=absolute', '--git-common-dir']), 'bbn');
  mkdirSync(d, { recursive: true });
  return d;
}
export function worktrees() {
  const out = git(['worktree', 'list', '--porcelain']);
  const list = []; let cur = null;
  for (const line of out.split('\n')) {
    if (line.startsWith('worktree ')) { cur = { path: line.slice(9), branch: null }; list.push(cur); }
    else if (line.startsWith('branch ') && cur) cur.branch = line.slice(7).replace('refs/heads/', '');
  }
  // A worktree mid-rebase is detached; it still belongs to the branch being rebased.
  for (const w of list) if (!w.branch && existsSync(w.path)) {
    const gd = git(['-C', w.path, 'rev-parse', '--absolute-git-dir'], { allowFail: true });
    for (const d of ['rebase-merge', 'rebase-apply']) {
      const f = typeof gd === 'string' && join(gd, d, 'head-name');
      if (f && existsSync(f)) w.branch = readFileSync(f, 'utf8').trim().replace('refs/heads/', '');
    }
  }
  return list;
}
export function ledger(event, fields = {}) {
  if (process.env.BBN_LEDGER === '0') return;
  let branch = '';
  try { branch = git(['rev-parse', '--abbrev-ref', 'HEAD']); } catch {}
  const line = JSON.stringify({ ts: new Date().toISOString().replace(/\.\d+Z$/, 'Z'), event, branch, ...fields });
  appendFileSync(join(commonDir(), 'runs.jsonl'), line + '\n');
}

// Minimal JSON-schema subset: type, const, enum, pattern, minimum, maximum, minItems,
// items, required, properties, additionalProperties(object).
const typeOf = (v) => Array.isArray(v) ? 'array' : Number.isInteger(v) ? 'integer' : v === null ? 'null' : typeof v;
export function validate(v, s, path = '$', errors = []) {
  if ('const' in s && v !== s.const) errors.push(`${path}: must be ${JSON.stringify(s.const)}`);
  if (s.enum && !s.enum.includes(v)) errors.push(`${path}: must be one of ${s.enum.join(', ')}`);
  if (s.type) {
    const t = typeOf(v);
    if (!(s.type === t || (s.type === 'number' && t === 'integer'))) { errors.push(`${path}: expected ${s.type}, got ${t}`); return errors; }
  }
  if (typeof v === 'number') {
    if (s.minimum !== undefined && v < s.minimum) errors.push(`${path}: < ${s.minimum}`);
    if (s.maximum !== undefined && v > s.maximum) errors.push(`${path}: > ${s.maximum}`);
  }
  if (typeof v === 'string') {
    if (s.minLength !== undefined && v.length < s.minLength) errors.push(`${path}: shorter than ${s.minLength}`);
    if (s.pattern && !new RegExp(s.pattern).test(v)) errors.push(`${path}: does not match ${s.pattern}`);
  }
  if (Array.isArray(v)) {
    if (s.minItems !== undefined && v.length < s.minItems) errors.push(`${path}: needs at least ${s.minItems} item(s)`);
    if (s.items) v.forEach((x, i) => validate(x, s.items, `${path}[${i}]`, errors));
  }
  if (typeOf(v) === 'object') {
    for (const r of s.required || []) if (!(r in v)) errors.push(`${path}.${r}: required`);
    for (const [k, x] of Object.entries(v)) {
      if (s.properties && s.properties[k]) validate(x, s.properties[k], `${path}.${k}`, errors);
      else if (s.additionalProperties && typeof s.additionalProperties === 'object') validate(x, s.additionalProperties, `${path}.${k}`, errors);
      else if (s.additionalProperties === false) errors.push(`${path}.${k}: unknown field`);
    }
  }
  return errors;
}
export const exists = existsSync;

// Plan checks shared by bbn-plan.mjs and bbn-run.mjs.
// A stream's identity: what it builds and how it is checked. bbn-merge.sh logs it with the merge.
export const streamId = (s) => 'st-' + createHash('sha256').update(JSON.stringify({ summary: s.summary || '', paths: s.paths, acceptance: s.acceptance })).digest('hex').slice(0, 12);
export const hashStreams = (p) => createHash('sha256').update(JSON.stringify({ goal: p.goal, base: p.base || '', streams: p.streams })).digest('hex').slice(0, 16);
const norm = (p) => p.replace(/^\.\//, '').replace(/\/+$/, '');
const overlaps = (a, b) => { const x = norm(a), y = norm(b); return x === y || x.startsWith(y + '/') || y.startsWith(x + '/') || x === '' || y === ''; };

export function checkPlan(plan, cfg = loadConfig()) {
  const errors = validate(plan, readJson(join(PLUGIN_ROOT, 'bbn.plan.schema.json')), 'plan');
  if (errors.length) return { errors, warnings: [] };
  const warnings = [];
  const slugs = new Map(plan.streams.map((s) => [s.slug, s]));
  if (slugs.size !== plan.streams.length) errors.push('streams: duplicate slug');
  const maxWt = cfg.budgets?.maxParallelWorktrees ?? 6;
  if (plan.streams.length > maxWt) errors.push(`streams: ${plan.streams.length} > maxParallelWorktrees (${maxWt}); split the plan into waves`);
  const minAcc = cfg.planValidation?.minAcceptanceChecks ?? 1;
  for (const s of plan.streams) {
    if (s.acceptance.length < minAcc) errors.push(`${s.slug}: needs at least ${minAcc} acceptance check(s)`);
    for (const p of s.paths) if (p.startsWith('/') || p.split('/').includes('..')) errors.push(`${s.slug}: path must be repo-relative: ${p}`);
    for (const d of s.dependsOn || []) {
      if (d === s.slug) errors.push(`${s.slug}: depends on itself`);
      else if (!slugs.has(d)) errors.push(`${s.slug}: depends on unknown stream ${d}`);
    }
  }
  const order = topo(plan, errors);
  // reach[a] = set of streams a (transitively) depends on
  const reach = new Map();
  for (const s of order) {
    const r = new Set();
    for (const d of slugs.get(s).dependsOn || []) { r.add(d); for (const x of reach.get(d) || []) r.add(x); }
    reach.set(s, r);
  }
  for (let i = 0; i < plan.streams.length; i++) for (let j = i + 1; j < plan.streams.length; j++) {
    const a = plan.streams[i], b = plan.streams[j];
    const shared = a.paths.filter((p) => b.paths.some((q) => overlaps(p, q)));
    if (!shared.length) continue;
    const ordered = reach.get(a.slug)?.has(b.slug) || reach.get(b.slug)?.has(a.slug);
    if (ordered) warnings.push(`${a.slug} and ${b.slug} share ${shared.join(', ')} (ordered by dependsOn; later one rebases on the earlier)`);
    else errors.push(`${a.slug} and ${b.slug} both own ${shared.join(', ')} with no dependsOn between them; give one owner or add an order`);
  }
  return { errors, warnings, order };
}
function topo(plan, errors) {
  const deps = new Map(plan.streams.map((s) => [s.slug, (s.dependsOn || []).filter((d) => d !== s.slug)]));
  const out = [], state = new Map();
  const visit = (n, stack) => {
    if (state.get(n) === 2) return;
    if (state.get(n) === 1) { errors.push(`dependsOn cycle: ${[...stack, n].join(' -> ')}`); return; }
    state.set(n, 1);
    for (const d of deps.get(n) || []) if (deps.has(d)) visit(d, [...stack, n]);
    state.set(n, 2); out.push(n);
  };
  for (const s of plan.streams) visit(s.slug, []);
  return out;
}

