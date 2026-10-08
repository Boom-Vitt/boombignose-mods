// Shared helpers for the BBN Node scripts (no dependencies).
import { execFileSync } from 'node:child_process';
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
